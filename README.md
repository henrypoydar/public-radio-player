# KCRW Player

A minimal macOS menu bar app for streaming KCRW radio to AirPlay speakers, isolated from your main audio output.

## Features

- **Menu bar only** - No dock icon, doesn't interfere with other apps
- **Three streams** - KCRW 89.9 (simulcast), Eclectic24, News24
- **Native AirPlay picker** - Route audio to any AirPlay speaker
- **Isolated audio** - Plays on selected AirPlay device while other apps use your default output

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
./build.sh
```

This compiles the Swift source and creates `build/KCRWPlayer.app`.

## Run

```bash
open build/KCRWPlayer.app
```

## Install

Copy to Applications for permanent installation:

```bash
cp -r build/KCRWPlayer.app /Applications/
```

To launch at login, add it via System Settings > General > Login Items.

## Usage

1. Click the radio icon in the menu bar
2. Select a stream (KCRW 89.9, Eclectic24, or News24)
3. Click **Play**
4. Click the **AirPlay button** (top right) to choose your speaker

## Stream URLs

| Stream | URL |
|--------|-----|
| KCRW 89.9 | `https://streams.kcrw.com/kcrw_mp3` |
| Eclectic24 | `https://streams.kcrw.com/e24_mp3` |
| News24 | `https://streams.kcrw.com/news24_mp3` |

## Project Structure

```
kcrw-player/
├── KCRWPlayer/
│   ├── main.swift          # App entry point
│   ├── AppDelegate.swift   # Menu bar UI, AirPlay picker
│   └── AudioPlayer.swift   # AVPlayer wrapper, stream management
├── build.sh                # Build script
└── README.md
```

## Troubleshooting

**App doesn't appear in menu bar:**
Check if it's running with `ps aux | grep KCRWPlayer`. If not, try running from terminal to see errors:
```bash
./build/KCRWPlayer.app/Contents/MacOS/KCRWPlayer
```

**AirPlay devices not showing:**
Ensure your AirPlay speakers are on the same network. The picker uses macOS's native AirPlay discovery.

**No audio:**
Click the AirPlay button and verify a device is selected. Check System Settings > Sound to confirm the app isn't muted.
