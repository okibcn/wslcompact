#  WslCompact 2023.03.01
#  (C) 2023 Oscar Lopez.
#  For more information visit: https://github.com/okibcn/wslcompact
#

function Format-Size([double]$mb) {
    if ($mb -ge 10240) { '{0:N1} GB' -f ($mb / 1024) }
    else { '{0:N0} MB' -f [math]::Round($mb) }
}

function Test-VhdxFree([string]$path) {
    try {
        $fs = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        $true
    }
    catch [System.IO.IOException] { $false }
    catch [System.IO.UnauthorizedAccessException] { $false }
    catch { $false }
}

function Test-SpaceOk([string]$path, [long]$neededBytes) {
    try {
        [IO.DriveInfo]::new([IO.Path]::GetPathRoot($path)).AvailableFreeSpace -gt $neededBytes
    }
    catch {
        Write-Host " Cannot query free space for '$path' ($($_.Exception.Message))." -ForegroundColor Yellow
        $false
    }
}

function Rename-WithRetry([string]$LiteralPath, [string]$NewName) {
    foreach ($i in 1..3) {
        try { Rename-Item -LiteralPath $LiteralPath -NewName $NewName -Force -ErrorAction Stop; return $true }
        catch { Start-Sleep 2 }
    }
    return $false
}

# Canonical MSVCRT argv quoting for wsl.exe arguments. The Start-Job scriptblock
# keeps its own duplicate because jobs cannot see module scope; this copy exists
# so Pester (InModuleScope) can test the quoting rules.
function ConvertTo-WslArg([string]$s) {
    $t = $s -replace '(\\+)$', '$1$1' -replace '(\\*)"', '$1$1\"'
    if ($s -match '[\s"]') { '"' + $t + '"' } else { $t }
}

<#
.SYNOPSIS
    Compacts WSL distro images by reclaiming unused space.
.DESCRIPTION
    Compacts the ext4 VHDX images of WSL2 distros by exporting and re-importing
    them through a temporary distro. With no options it runs in read-only info
    mode. Compacting (-c) shuts WSL down and needs free disk space roughly equal
    to the largest selected image on BOTH %TEMP%'s drive and each image's drive.
.PARAMETER PassThru
    Emit one result object per processed distro (Distro, Path, OldMB, NewMB,
    SavedMB, Action, Success). Action is one of: Info, Bypassed, Missing, Error,
    Locked, Replaced, Kept, Discarded, NoSpace.
.PARAMETER Version
    Prints the version and exits.
.NOTES
    Temp work happens in %TEMP%\wslcompact. Info mode briefly starts each distro
    VM to measure used space. -y requires -c. Data images (names ending in
    '-data') are skipped unless -d is given.
.EXAMPLE
    PS> wslcompact
    Info mode: name, path, current and estimated sizes for all distros.
.EXAMPLE
    PS> wslcompact Ubuntu
    Info mode, Ubuntu only.
.EXAMPLE
    PS> wslcompact -c Ubuntu
    Compact Ubuntu, asking for confirmation before replacing the image.
.EXAMPLE
    PS> wslcompact -c -d -y Ubuntu Kali
    Compact including data images, without confirmation prompts.
#>
function WslCompact {
    [CmdletBinding()]
    param(
        [Alias('c')] [switch]$Compact,
        [Alias('y')] [switch]$Force,
        [Alias('d')] [switch]$Data,
        [Alias('h')] [switch]$Help,
        [Alias('v')] [switch]$Version,
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$TargetDistros,
        [switch]$PassThru
    )
    if ($TargetDistros) {
        foreach ($name in $TargetDistros) {
            if (-not $name.Trim() -or $name.StartsWith('-')) {
                throw "WslCompact: unknown option '$name'. Run 'wslcompact -Help'."
            }
        }
    }
    $V = if ($m = Get-Module WslCompact) { $m.Version } else { [version](Import-PowerShellDataFile "$PSScriptRoot/WslCompact.psd1").ModuleVersion }
    $sf = 1.05
    $mb_per_min = 4000 # rough SSD throughput for the time estimate; HDDs are slower
    $results = [System.Collections.Generic.List[object]]::new()
    $sw_run = [Diagnostics.Stopwatch]::StartNew()
    if ($Version) { Write-Host " WslCompact v$V"; return }
    # wsl.exe emits UTF-16LE when redirected; WSL_UTF8=1 (wsl >= 0.64) makes its
    # output UTF-8 so PS 5.1 parses it reliably. Restored in the finally block.
    $prev_utf8 = $env:WSL_UTF8
    $env:WSL_UTF8 = '1'
    $prev_oenc = try { [Console]::OutputEncoding.WebName } catch { $null }
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    try {
        if ($Help) {
            Write-Host "

 Usage: wslcompact [OPTIONS] [DISTROS]

 wslcompact compacts the images of WSL distros by removing unused space.
 If no option is provided, it will default to info mode, without modifying any image.
 If no distro is provided it will process all the installed images.
 NOTE: WSL will be shutdown for compacting the images.

 Options:
  no opt. Provides distro name, path, size, and estimated new size information.
     -c   Compacting mode: process the selected distros compacting the images.
     -y   replaces selected images without asking for confirmation (also skips the shutdown prompt).
     -d   Enable the processing of data images (names ending in '-data'). Default is disabled.
     -v   Prints the version.
     -h   Prints this help

 Examples:
      wslcompact
      wslcompact Ubuntu
      wslcompact -c Ubuntu
      wslcompact -c -d -y Ubuntu Kali

 Long forms -Compact, -Force, -Data, -Help, -Version are accepted. Bundled short
 flags like -cy are not supported. See also: Get-Help WslCompact.
      "
            return
        }
        if ($Force -and -not $Compact) {
            Write-Host " NOTE: -y has no effect without -c." -ForegroundColor Yellow
        }
        Write-Host " WslCompact v$V 2023.03.01
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact"
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            Write-Host " WARNING: wsl.exe not found. Is WSL installed?" -ForegroundColor Yellow
            return
        }
        $lines = @(wsl.exe --version 2>$null)
        $wsl_version = ''
        if ($lines.Count -gt 0 -and $LASTEXITCODE -eq 0) { $wsl_version = (($lines[0] -replace "`0", '') -split '\s+')[-1] }
        $wsl_v = [version]'0.0'
        [void][version]::TryParse($wsl_version, [ref]$wsl_v)
        if ($wsl_v -lt [version]'1.0') {
            Write-Host "
WARNING:
    you are using WSL version '$wsl_version'. wslcompact requires WSL version 1.0.0 or higher.
    You can update WSL typing: wsl --update in PowerShell or using the Microsoft Store.

" -ForegroundColor Yellow
            return
        }
        if ($Compact) {
            $raw_running = @(wsl --list --running 2>$null)
            $known = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*' -ErrorAction SilentlyContinue |
                ForEach-Object { (Get-ItemProperty $_.PSPath).DistributionName })
            $running = @($raw_running | Where-Object {
                    ($_ -replace "\x00", '').Trim() -and (($_ -replace "\x00", '').Trim()) -in $known
                })
            if ($running) {
                Write-Host "`n WARNING: compacting runs 'wsl --shutdown', stopping ALL running distros," -ForegroundColor Yellow
                Write-Host " sessions and the Docker Desktop backend -- not just selected images:" -ForegroundColor Yellow
                Write-Host "   $($running -join ', ')`n" -ForegroundColor Yellow
                if (!$Force -and (Read-Host ' Stop them and continue? (y/N)') -notmatch '^[Yy]') {
                    return
                }
            }
        }
    $tmp_folder = "$Env:TEMP\wslcompact"
    $drive_root = if ($env:TEMP) { [IO.Path]::GetPathRoot($env:TEMP) } else { '' }
    $freedisk = try { if ($drive_root -match '^[A-Za-z]:') { (Get-PSDrive $drive_root[0]).Free } else { $null } } catch { $null }
    if ($null -eq $freedisk) {
        Write-Host " WARNING: cannot determine free space for TEMP '$(if ($env:TEMP) { $env:TEMP } else { '<not set>' })'. Free-space check skipped." -ForegroundColor Yellow
    }
    mkdir "$tmp_folder" -ErrorAction SilentlyContinue | Out-Null
    $keep_tmp = $false
    $processed = @()
    $keys = @(Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\`{*" -ErrorAction SilentlyContinue)
    $ghost_registered = {
        [bool](Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*' -ErrorAction SilentlyContinue |
            Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DistributionName -eq 'wslcompact' })
    }
    if (& $ghost_registered) {
        Write-Host " WARNING: cleaning stale temp distro left by an interrupted run." -ForegroundColor Yellow
        wsl --shutdown
        wsl --unregister wslcompact 2>$null
    }
    Write-Host " NOTE: measuring used space briefly starts each distro VM. Sessions elsewhere are left untouched."
    try {
        foreach ($key in $keys) {
        $wsl_ = Get-ItemProperty $key.PSPath
        $wsl_distro = $wsl_.DistributionName
        $base = [string]$wsl_.PSObject.Properties['BasePath'].Value
        if ([string]::IsNullOrEmpty($base)) {
            Write-Warning " Skipping '$($key.PSChildName)': Lxss key has no BasePath."
            continue
        }
        $wsl_path = if ($base.StartsWith('\\?\')) { $base.Substring(4) } else { $base }
        $vhd_name = if ($wsl_.PSObject.Properties['VhdFileName']) { [string]$wsl_.VhdFileName } else { 'ext4.vhdx' }
        $vhd_path = Join-Path $wsl_path $vhd_name
        $data_image = $wsl_distro -like '*-data'
        if ( !$TargetDistros -or ($wsl_distro -in $TargetDistros) ) {
            # The wsl_distro is marked for processing
            $processed += $wsl_distro
            if (!(Test-Path -LiteralPath $vhd_path)) {
                Write-Host " WARNING: image '$vhd_path' not found for $wsl_distro. Skipping." -ForegroundColor Yellow
                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $null; NewMB = $null; SavedMB = $null; Action = 'Missing'; Success = $false })
                continue
            }
            $size1 = (Get-Item -LiteralPath $vhd_path).Length / 1MB
            Write-Host "`nDistro name: $wsl_distro" -ForegroundColor Cyan
            Write-Host "Image file: $vhd_path" -ForegroundColor Cyan
            Write-Host "Current size: $(Format-Size $size1)"
            if ($data_image) {
                Write-Host " The image is not a WSL OS, but a data partition. No size estimation is available at this time."
                $estimated = [long]($size1)
            }
            else {
                $dfout = (wsl -u root -d "$wsl_distro" sh -c 'command -v df >/dev/null && df -P /' 2>$null)
                $usedkb = ($dfout | sls -Pattern "(?<=^\/dev[^\s]+\s+\d+\s+)\d+").Matches[0].Value
                if (!$usedkb -or ([long]$usedkb -le 0)) {
                    Write-Host " Cannot estimate used space (missing df or uninitialized distro). Using current image size as estimate."
                    $estimated = [long]($size1)
                }
                else {
                    $estimated = [long]($usedkb / 1024)
                    Write-Host "Estimated new size: $(Format-Size $estimated) (range: $(Format-Size $estimated) to $(Format-Size ($estimated * $sf)))"
                    $mins = [math]::ceiling($estimated / $mb_per_min)
                    Write-Host " The estimated process time using an SSD is about $mins minute$(if ($mins -ne 1) { 's' })."
                }
            }
            $need = [long]($estimated * $sf * 1MB)
            $space_ok = if ($Compact) { ((($null -eq $freedisk) -or (Test-SpaceOk $tmp_folder $need)) -and (Test-SpaceOk $vhd_path $need)) } else { $true }
            if ($space_ok) {
                if ($Compact) {
                    # we are in compact mode, we process the image.
                    if ((!$Data) -and ($data_image)) {
                        Write-Host " Bypassing data image. Use -d option to force processing of data images." -ForegroundColor Yellow
                        $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Bypassed'; Success = $true })
                        Continue
                    }
                    Write-Host " NOTE: You can safely cancel at any time by pressing Ctrl-C`n " -NoNewLine
                    if (-not $keep_tmp) { remove-item "$tmp_folder/*" -Recurse -Force }
                    wsl --shutdown
                    $pipe_failed = $false
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    # Byte-faithful export->import via two direct processes (no cmd.exe):
                    # PS 5.1 native piping decodes binary tar as text and corrupts it,
                    # so the copy loop runs on raw BaseStreams inside a background job.
                    $job = Start-Job -ArgumentList $wsl_distro, $tmp_folder {
                        param($distro, $dest)
                        function ConvertTo-WslArg([string]$s) {
                            $t = $s -replace '(\\+)$', '$1$1' -replace '(\\*)"', '$1$1\"'
                            if ($s -match '[\s"]') { '"' + $t + '"' } else { $t }
                        }
                        $mk = {
                            param($argline)
                            $p = New-Object System.Diagnostics.ProcessStartInfo
                            $p.FileName = "$env:SystemRoot\System32\wsl.exe"
                            $p.Arguments = $argline
                            $p.UseShellExecute = $false
                            $p.CreateNoWindow = $false
                            $p.RedirectStandardOutput = $true
                            $p.RedirectStandardInput = $true
                            [System.Diagnostics.Process]::Start($p)
                        }
                        $pe = & $mk "--export $(ConvertTo-WslArg $distro) -"
                        $pi = & $mk "--import wslcompact $(ConvertTo-WslArg $dest) -"
                        try {
                            $buf = New-Object byte[] 1048576
                            $stdin = $pi.StandardInput.BaseStream
                            while (($n = $pe.StandardOutput.BaseStream.Read($buf, 0, $buf.Length)) -gt 0) { $stdin.Write($buf, 0, $n) }
                            $stdin.Flush(); $stdin.Close()
                            $pi.WaitForExit(); $pe.WaitForExit()
                            if ($pi.ExitCode -ne 0) { throw "wsl import failed with exit code $($pi.ExitCode)" }
                            if ($pe.ExitCode -ne 0) { throw "wsl export failed with exit code $($pe.ExitCode)" }
                        }
                        finally {
                            foreach ($proc in @($pe, $pi)) {
                                if ($proc -and -not $proc.HasExited) { try { $proc.Kill() } catch { } }
                            }
                        }
                    }
                    try {
                        while ($job.State -eq 'Running') {
                            $cur = (Get-Item "$tmp_folder\ext4.vhdx" -ErrorAction SilentlyContinue).Length
                            $exp = [Math]::Max(1MB, $estimated * $sf * 1MB)
                            if ($cur) {
                                Write-Progress -Activity "Compacting $wsl_distro" -Status ("Importing {0:N0} of about {1:N0} MB" -f ($cur / 1MB), ($exp / 1MB)) `
                                    -PercentComplete ([Math]::Min(95, [int](100 * $cur / $exp))) `
                                    -SecondsRemaining ([int]($sw.Elapsed.TotalSeconds * ($exp - $cur) / $cur))
                            }
                            else {
                                Write-Progress -Activity "Compacting $wsl_distro" -Status "Exporting image... elapsed $($sw.Elapsed.ToString('mm\:ss'))"
                            }
                            Start-Sleep -Milliseconds 500
                        }
                        Write-Progress -Activity "Compacting $wsl_distro" -Completed
                        $pipe_errs = @()
                        Receive-Job $job -ErrorAction SilentlyContinue -ErrorVariable pipe_errs | Out-Null
                    }
                    finally {
                        if ($job.State -eq 'Running') { Stop-Job $job }
                        Remove-Job $job -Force -ErrorAction SilentlyContinue
                    }
                    # State-based detection: our explicit throws put the job in 'Failed';
                    # stray child stderr alone does not fail the job state.
                    if ($job.State -ne 'Completed') {
                        $pipe_failed = $true
                        $errmsg = if ($pipe_errs) { $pipe_errs[0].Exception.Message } else { "job ended in state $($job.State)" }
                        $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                        Write-Host ""
                        Write-Host " ERROR: export/import failed: $errmsg" -ForegroundColor Red
                        Write-Host "        Original image untouched." -ForegroundColor Red
                    }
                    if ($pipe_failed) {
                        if (& $ghost_registered) { wsl --shutdown 2>$null; wsl --unregister wslcompact 2>$null | Out-Null }
                    }
                    else {
                        foreach ($i in 1..5) { if (Test-VhdxFree "$tmp_folder/ext4.vhdx") { break }; Start-Sleep 1 }
                        if (-not (Test-VhdxFree "$tmp_folder/ext4.vhdx")) { wsl --shutdown }
                    }
                    $vhd = Get-Item "$tmp_folder/ext4.vhdx" -ErrorAction SilentlyContinue
                    $vhd_ok = ($null -ne $vhd) -and (-not $pipe_failed) -and
                        ($vhd.Length -ge 1MB) -and ($vhd.Length -le (($size1 * 1MB) * 1.1 + 10MB))
                    if ($vhd_ok) {
                        $fs = [IO.File]::OpenRead($vhd.FullName); $sig = New-Object byte[] 8
                        $null = $fs.Read($sig, 0, 8); $fs.Close()
                        $vhd_ok = ([Text.Encoding]::ASCII.GetString($sig) -eq 'vhdxfile')
                    }
                    if ($vhd_ok) {
                        try { Move-Item "$tmp_folder/ext4.vhdx" "$tmp_folder/$wsl_distro.vhdx" -Force -ErrorAction Stop }
                        catch {
                            $pipe_failed = $true
                            $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                            Write-Host " ERROR: could not rename the imported image: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host "        Original image untouched." -ForegroundColor Red
                            continue
                        }
                        wsl --unregister wslcompact | Out-Null
                        $size2 = (Get-Item -Path "$tmp_folder/$wsl_distro.vhdx").Length / 1MB
                        Write-Host " New Image compacted from $(Format-Size $size1) to $(Format-Size $size2)" -ForegroundColor Green
                        $answer = if ($Force) { 'y' } else { read-host -prompt " Do you want to apply changes and use the new image (y/N)" }
                        if ($answer -match '^(y|yes)$') {
                            $new = "$tmp_folder/$wsl_distro.vhdx"
                            $stg = "$vhd_path.new"
                            $bak = "$vhd_path.bak"
                            $need = [long]($estimated * $sf * 1MB)
                            $tgt_root = [IO.Path]::GetPathRoot($vhd_path)
                            try { $tgt_free = [IO.DriveInfo]::new($tgt_root).AvailableFreeSpace } catch { $tgt_free = 0 }
                            if ($need -gt $tgt_free) {
                                Write-Host " WARNING: not enough free space on '$tgt_root' to stage the new image (need about $(Format-Size ($need / 1MB))). Original image untouched." -ForegroundColor Yellow
                                Write-Host " Compacted image kept at $new." -ForegroundColor Yellow
                                Write-Host " Finish later: shut WSL down, then Move-Item -Force '$new' '$vhd_path'" -ForegroundColor Yellow
                                $keep_tmp = $true
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'NoSpace'; Success = $false })
                                continue
                            }
                            if (Test-Path -LiteralPath $bak) {
                                Write-Host " Removed leftover backup $bak (superseded)."
                                Remove-Item -LiteralPath $bak -Force
                            }
                            Copy-Item -LiteralPath $new -Destination $stg -Force
                            if ((Get-Item -LiteralPath $stg).Length -ne (Get-Item -LiteralPath $new).Length) {
                                Write-Host " WARNING: could not stage the new image onto '$tgt_root'. Original untouched; compacted image kept at $new." -ForegroundColor Yellow
                                Write-Host " Finish later: shut WSL down, then Move-Item -Force '$new' '$vhd_path'" -ForegroundColor Yellow
                                $keep_tmp = $true
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = [long]$size2; SavedMB = [long]($size1 - $size2); Action = 'Error'; Success = $false })
                                continue
                            }
                            foreach ($i in 1..3) { if (Test-VhdxFree $vhd_path) { break }; Start-Sleep 2 }
                            if (-not (Test-VhdxFree $vhd_path)) {
                                wsl --shutdown
                                Start-Sleep 2
                            }
                            if (-not (Rename-WithRetry -LiteralPath $vhd_path -NewName "$vhd_name.bak")) {
                                Write-Host " WARNING: original image '$vhd_path' is locked; replace skipped. Compacted image kept at $new." -ForegroundColor Yellow
                                Write-Host " Finish later: shut WSL down, then Move-Item -Force '$new' '$vhd_path'" -ForegroundColor Yellow
                                Remove-Item -LiteralPath $stg -Force -ErrorAction SilentlyContinue
                                $keep_tmp = $true
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Locked'; Success = $false })
                                continue
                            }
                            if (-not (Rename-WithRetry -LiteralPath $stg -NewName $vhd_name)) {
                                if (-not (Rename-WithRetry -LiteralPath $bak -NewName $vhd_name)) {
                                    Write-Host " CRITICAL: could not restore the original image. It is kept at '$bak'." -ForegroundColor Red
                                    Write-Host " Restore it manually: Move-Item -Force '$bak' '$vhd_path'" -ForegroundColor Red
                                    $keep_tmp = $true
                                }
                                else {
                                    Write-Host " WARNING: could not move the new image into place. Original restored; compacted copy kept at $new." -ForegroundColor Yellow
                                    Write-Host " Finish later: shut WSL down, then Move-Item -Force '$new' '$vhd_path'" -ForegroundColor Yellow
                                    $keep_tmp = $true
                                }
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                                continue
                            }
                            if ((Get-Item -LiteralPath $vhd_path).Length -eq (Get-Item -LiteralPath $new).Length) {
                                Remove-Item -LiteralPath $new -Force
                                Write-Host " Image replaced for distro: $wsl_distro" -ForegroundColor Green
                                Write-Host " Previous image kept at $bak -- verify the distro boots, then delete it or let the next run prune it."
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $size2; SavedMB = [long]($size1 - $size2); Action = 'Replaced'; Success = $true })
                            }
                            else {
                                Remove-Item -LiteralPath $vhd_path -Force -ErrorAction SilentlyContinue
                                if (-not (Rename-WithRetry -LiteralPath $bak -NewName $vhd_name)) {
                                    Write-Host " CRITICAL: replaced image failed verification AND the original could not be restored." -ForegroundColor Red
                                    Write-Host " The original is kept at '$bak'. Restore it manually: Move-Item -Force '$bak' '$vhd_path'" -ForegroundColor Red
                                    $keep_tmp = $true
                                    $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                                }
                                else {
                                    Write-Host " WARNING: replaced image failed verification. Original restored. Compacted copy discarded (failed length check)." -ForegroundColor Yellow
                                    $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                                }
                            }
                        }
                        else {
                            Write-Host " Compacted image saved $(Format-Size ($size1 - $size2))."
                            $answer2 = Read-Host -Prompt " Keep image at $tmp_folder\$wsl_distro.vhdx or delete? (K/D)"
                            if ($answer2 -match '^[kK]') {
                                $keep_tmp = $true
                                Write-Host " Kept: $tmp_folder\$wsl_distro.vhdx ($(Format-Size $size2))."
                                Write-Host " Apply later: shut WSL down, copy over $vhd_path."
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = "$tmp_folder\$wsl_distro.vhdx"; OldMB = $size1; NewMB = $size2; SavedMB = [long]($size1 - $size2); Action = 'Kept'; Success = $true })
                            }
                            else {
                                Write-Host " Discarded compacted image ($(Format-Size ($size1 - $size2)) potential saving lost)."
                                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Discarded'; Success = $true })
                            }
                        }
                    }
                    elseif ($pipe_failed) {
                        # Pipe failure already reported above; nothing else to do.
                    }
                    else {
                        Write-Host " WARNING: export/import produced no usable image for '$wsl_distro'. $vhd_path was NOT modified." -ForegroundColor Red
                        $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'Error'; Success = $false })
                        Write-Host " Likely causes and fixes, in order:" -ForegroundColor Red
                        Write-Host "   1. Locked distro files -> run 'wsl --shutdown', then re-run wslcompact" -ForegroundColor Red
                        Write-Host "   2. Low space on TEMP drive -> need about $(Format-Size ($estimated * $sf)) free" -ForegroundColor Red
                        Write-Host "   3. Windows disk errors -> chkdsk /scan" -ForegroundColor Red
                        Write-Host "   4. Linux filesystem corruption -> wsl -d ""$wsl_distro"" -u root fsck.ext4 -f /" -ForegroundColor Red
                        Write-Host "   5. Leftover partial import -> if 'wslcompact' shows in 'wsl -l': wsl --unregister wslcompact" -ForegroundColor Red
                        Write-Host " Report: https://github.com/okibcn/wslcompact/issues" -ForegroundColor Red
                        if (& $ghost_registered) {
                            Write-Host " NOTE: a stale 'wslcompact' temp distro was detected (interrupted earlier run)." -ForegroundColor Yellow
                            Write-Host "       That is the likely cause, not image corruption. It is removed when this" -ForegroundColor Yellow
                            Write-Host "       run ends -- just run wslcompact again." -ForegroundColor Yellow
                        }
                    }
                }
            }
            else {
                # There isn't enough free space on the TEMP drive and/or the image drive
                write-Host " WARNING: not enough free space to process $wsl_distro." -ForegroundColor Yellow
                write-Host "Need about $(Format-Size ($estimated * $sf)) free on BOTH the TEMP drive ($drive_root) and the image drive ($([IO.Path]::GetPathRoot($vhd_path)))." -ForegroundColor Yellow
                write-Host ""
                write-Host "Please change the TEMP folder to a drive with at least $(Format-Size ($estimated * $sf)) of free space." -ForegroundColor Yellow
                write-Host "You can do it by typing `$env:TEMP=`"<path with enough space>`" before using wslcompact.`n"
                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $null; SavedMB = $null; Action = 'NoSpace'; Success = $false })
            }
            if (-not $Compact) {
                $results.Add([pscustomobject]@{ Distro = $wsl_distro; Path = $vhd_path; OldMB = $size1; NewMB = $estimated; SavedMB = [long]($size1 - $estimated); Action = 'Info'; Success = $true })
            }
        }
        }
    }
    finally {
        if (-not $keep_tmp) { Remove-Item -Recurse -Force "$tmp_folder" -ErrorAction SilentlyContinue }
        if (& $ghost_registered) { wsl --shutdown 2>$null; wsl --unregister wslcompact 2>$null | Out-Null }
    }
    if ($Compact -and $results.Count) {
        $saved_total = ($results | Measure-Object -Property SavedMB -Sum).Sum
        $results | ForEach-Object {
            [pscustomobject]@{
                Distro = $_.Distro
                Before = if ($null -ne $_.OldMB) { Format-Size $_.OldMB } else { '-' }
                After  = if ($null -ne $_.NewMB) { Format-Size $_.NewMB } else { '-' }
                Saved  = if ($null -ne $_.SavedMB) { Format-Size $_.SavedMB } else { '-' }
                Status = $_.Action
            }
        } | Format-Table -AutoSize | Out-Host
        Write-Host (" Total saved: {0} in {1:mm\:ss}" -f (Format-Size ([double]$saved_total)), $sw_run.Elapsed)
    }
    if ($PassThru) { $results }
    if ($TargetDistros) {
        $missing = @($TargetDistros | Where-Object { $_ -notin $processed })
        if ($missing) {
            Write-Error "Distro(s) not found: $($missing -join ', '). Run 'wsl -l' to list installed distros." -ErrorAction Stop
        }
    }
    write-Host ""
    }
    finally {
        if ($null -eq $prev_utf8) { Remove-Item Env:\WSL_UTF8 -ErrorAction SilentlyContinue }
        else { $env:WSL_UTF8 = $prev_utf8 }
        if ($null -ne $prev_oenc) { try { [Console]::OutputEncoding = [Text.Encoding]::GetEncoding($prev_oenc) } catch { } }
    }
}
Export-ModuleMember -Function 'WslCompact'
