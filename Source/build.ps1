$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path (Split-Path $PSScriptRoot -Parent) 'VoiceHost.exe'
& $compiler /nologo /target:winexe /platform:x64 ("/out:"+$output) (Join-Path $PSScriptRoot 'VoiceHost.cs')
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
