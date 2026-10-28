[CmdletBinding()]
param([string]$DestinationDirectory)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('DestinationDirectory')) { $DestinationDirectory = $PSScriptRoot }
$launcherPath = Join-Path $PSScriptRoot 'Start ZipVoice GUI.cmd'
$iconPath = Join-Path $PSScriptRoot 'assets\zipvoice.ico'
foreach ($file in @($launcherPath, $iconPath)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required file not found: $file" }
}
if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
    throw "Shortcut destination folder not found: $DestinationDirectory"
}
$destination = (Resolve-Path -LiteralPath $DestinationDirectory).ProviderPath
$shortcutPath = Join-Path $destination 'ZipVoice.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $null
try {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ((Test-Path -LiteralPath $shortcutPath) -and $shortcut.TargetPath -ne $launcherPath) {
        throw "A shortcut for another target already exists at $shortcutPath; it was left unchanged."
    }
    $shortcut.TargetPath = $launcherPath
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "$iconPath,0"
    $shortcut.Description = 'Start ZipVoice text to speech'
    $shortcut.Save()
    Write-Output $shortcutPath
} finally {
    if ($shortcut) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) | Out-Null }
    [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null
}
