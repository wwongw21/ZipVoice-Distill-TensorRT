param([string]$DestinationDirectory=[Environment]::GetFolderPath('Desktop'))
$ErrorActionPreference='Stop'
$target=Join-Path $PSScriptRoot 'Start ZipVoice Native.cmd'
if(-not(Test-Path -LiteralPath $target)){throw 'The native start entrypoint is missing'}
$path=Join-Path $DestinationDirectory 'ZipVoice Native (Experimental).lnk'
$shell=New-Object -ComObject WScript.Shell
$link=$shell.CreateShortcut($path)
if((Test-Path -LiteralPath $path) -and $link.TargetPath -and -not [IO.Path]::GetFullPath($link.TargetPath).Equals([IO.Path]::GetFullPath($target),[StringComparison]::OrdinalIgnoreCase)){
 throw 'An unrelated shortcut already uses this name; it was preserved'
}
$link.TargetPath=$target
$link.WorkingDirectory=$PSScriptRoot
$link.Description='Separate experimental native backend. Use Stop ZipVoice Native.cmd to stop it safely.'
$link.WindowStyle=1
$icon=Join-Path $PSScriptRoot 'assets\zipvoice.ico'
if(Test-Path -LiteralPath $icon){$link.IconLocation=$icon+',0'}
$link.Save()
Write-Host "Native shortcut saved: $path"
