$ErrorActionPreference='Stop'
$source=Join-Path (Split-Path $PSScriptRoot -Parent) 'Start ZipVoice Native.ps1'
$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$null,[ref]$errors)
if($errors.Count){throw 'Native PowerShell source does not parse'}
$ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Parent -eq $ast.EndBlock},$true) |
 ForEach-Object {Invoke-Expression $_.Extent.Text}
$folder=Join-Path $env:TEMP ('zvn-native-tests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$passed=0
function Assert-True {param([bool]$Condition,[string]$Text) if(-not $Condition){throw $Text}}
try {
 $py=Join-Path $folder "echo args's.py"
 [IO.File]::WriteAllText($py,'import sys,json;print(json.dumps({"args":sys.argv[1:]}))',[Text.UTF8Encoding]::new($false))
 $values=@('','has spaces',"has'apostrophe",'C:\a path\','has"quote','literal; & | tokens')
 $r=Invoke-OwnedNative 'python' (@($py)+$values) '' 10000
 Assert-True ($r.ExitCode -eq 0) 'Argument echo failed'
 $decoded=$r.Output | ConvertFrom-Json; $actual=@($decoded.args)
 Assert-True ($actual.Count -eq $values.Count) 'Argument count changed'
 for($i=0;$i -lt $values.Count;$i++){Assert-True ($actual[$i] -ceq $values[$i]) "Argument $i changed"}
 $passed++;Write-Host 'PASS exact native argument boundaries'
 $r=Invoke-OwnedNative 'python' @('-c','import sys;print(sys.stdin.read())') '{"space":"a b","apostrophe":"a''b"}' 10000
 Assert-True ($r.Output.Trim() -ceq '{"space":"a b","apostrophe":"a''b"}') 'JSON stdin changed'
 $passed++;Write-Host 'PASS JSON configuration stdin'
 $failed=$false
 try{Invoke-OwnedNative 'python' @('-c','import time;time.sleep(10)') '' 150 | Out-Null}catch{$failed=$true}
 Assert-True $failed 'Stalled owned command was accepted'
 $passed++;Write-Host 'PASS bounded owned process timeout'
 $r=Invoke-OwnedNative 'python' @('-c','import sys;sys.exit(7)') '' 10000
 Assert-True ($r.ExitCode -eq 7) 'Failure exit code became success'
 $passed++;Write-Host 'PASS native failure readback'
 $template=Join-Path (Split-Path $PSScriptRoot -Parent) 'NativeConfig.example.json'
 $profilePath=Join-Path $folder 'profile.json'
 $profile=Read-NativeProfile $profilePath $template
 Assert-True ([double]$profile.StartupTimeoutSeconds -eq 7800) 'Default phase budget changed'
 $passed++;Write-Host 'PASS private profile default and separate phase budget'
 $profile.StartupTimeoutSeconds=7500
 $profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $profilePath -Encoding utf8
 $failed=$false
 try{Read-NativeProfile $profilePath $template | Out-Null}catch{$failed=$true}
 Assert-True $failed 'Startup budget failed to include verification phases'
 $passed++;Write-Host 'PASS insufficient startup phase budget rejected'
 Write-Host "Native Windows seam checks passed: $passed"
} finally {
 $absolute=[IO.Path]::GetFullPath($folder);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
 if(-not $absolute.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path $absolute -Leaf).StartsWith('zvn-native-tests-')){throw 'Fixture cleanup boundary mismatch'}
 Remove-Item -LiteralPath $absolute -Recurse -Force
}
