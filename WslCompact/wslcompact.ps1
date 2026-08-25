# Portable entry point (winget/zip installs).
# Imports the module from this folder and forwards all arguments.
Import-Module -Name (Join-Path $PSScriptRoot 'WslCompact.psd1') -Force -ErrorAction Stop
WslCompact @args
