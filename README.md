# Rogue Warrior Player Voices — security review

Source and SHA-256 evidence for the **v0.1.2** release of the Incursion: Red River player voice mod.

Mod page: [Nexus Mods 296](https://www.nexusmods.com/incursionredriver/mods/296).

## For reviewers

- [Audio helper source](Source/VoiceHost.cs) and [build script](Source/build.ps1).
- [Lua integration](Scripts), including the launcher, event handling, playback scheduler and volume setting.
- [Build instructions](BUILD.md).
- [Original release hashes](RELEASE_HASHES.txt) and [review notes](REVIEW_REPORT.txt).
- [Source file hashes](SHA256SUMS.txt).

This repository contains review materials. Audio recordings, compiled executables, runtime data and the release ZIP are excluded. It is not an installable mod download.

## What the helper does

The unsigned Windows .NET Framework helper plays local PCM16 WAV clips with `System.Media.SoundPlayer`. A single worker and named mutex serialize playback. Lua exchanges commands, completion acknowledgements and heartbeats through local files under the mod's `Runtime` directory. The helper checks whether the game process is running so map loading does not end the audio session.

No networking, downloads, microphone recording, privilege elevation, registry modifications, memory injection or anti-debug functionality appears in the reviewed C# source. See the review notes for scope and limitations.

## Scan review

The original ZIP and helper have antivirus detections and are preserved unchanged for independent review. Source review alone does not establish that the compiled executable is safe or prove that the detections are false positives. This repository does not represent clearance from Nexus or an antivirus vendor.

- [Original ZIP on VirusTotal](https://www.virustotal.com/gui/file/31f7e043587882954260ccc29ebb452769bdbc9a3421415521c428caae434377)
- [VoiceHost.exe on VirusTotal](https://www.virustotal.com/gui/file/e1209d7c25227b4f5288cde70c5865aaee9af53d97ff40616969dc235279a23a)

Historical scan counts in the notes were observed on November 7, 2026; reports can change.
