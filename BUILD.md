# Building the audio helper

Use Windows with the .NET Framework 4.x C# compiler installed at:

`%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`

From the repository root, run in PowerShell:

```powershell
& .\Source\build.ps1
```

The script compiles `Source/VoiceHost.cs` as an x64 Windows application and writes `VoiceHost.exe` in the repository root. It uses framework assemblies and has no package downloads or third-party build dependencies. This only compiles the helper; it does not run it or install the mod. The audio assets and UE4SS runtime required for gameplay are not included here.

The compiler command is:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /platform:x64 /out:VoiceHost.exe Source\VoiceHost.cs
```

`Source/Tests` contains the Lua adapter and scheduler mock tests for additional inspection. They are separate from the C# build and do not verify the compiled PE or replace in-game testing.

## Hash verification

`RELEASE_HASHES.txt` identifies the original release ZIP and its helper. Those files are not hosted in this repository. A fresh build can have a different hash because of compiler metadata; matching source does not by itself prove binary equivalence.

`SHA256SUMS.txt` covers the repository's review files, except itself and `.git` metadata. Hashes describe the LF-normalized committed files. For example:

```powershell
Get-FileHash -Algorithm SHA256 .\Source\VoiceHost.cs
```
