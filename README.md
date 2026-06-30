# Public Radio Player

A minimal macOS menu bar app for streaming public radio to AirPlay speakers, isolated from your main audio output.

Please consider supporting these stations:
- **KCRW** - Music discovery, NPR and local news, culture coverage, and community events: https://join.kcrw.com/
- **WNYC** - Award-winning journalism, groundbreaking podcasts, and essential New York conversation: https://pledge.wnyc.org/
- **Radio France** - Public service radio from France, including FIP: https://www.radiofrance.fr/
- **BBC** - UK public broadcasting, including Radio 4: https://www.bbc.co.uk/sounds

## Features

- **Menu bar only** - No dock icon, doesn't interfere with other apps
- **Four stations** - KCRW (Los Angeles), WNYC (New York City), Radio France, and BBC
- **Eight streams** - KCRW 89.9, Eclectic24, News24, WNYC FM 93.9, WNYC AM 820, New Sounds, FIP, Radio 4
- **Native AirPlay picker** - Route audio to any AirPlay speaker
- **Isolated audio** - Plays on selected AirPlay device while other apps use your default output
- **CLI control** - Drive the player from the terminal with `prp` (list, status, play, pause, switch)


|<img width="222" height="516" alt="preview" src="https://github.com/user-attachments/assets/c62d0d9e-c3e5-4736-a979-cec5d7a16b24" />|<img width="346" height="246" alt="preview-output" src="https://github.com/user-attachments/assets/7bd3b8aa-ace8-40e8-9e93-677b29ac93f3" />|

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
./build.sh
```

This compiles the Swift source and creates `build/PublicRadioPlayer.app`.

## Run

```bash
open build/PublicRadioPlayer.app
```

## Install

Copy to Applications for permanent installation:

```bash
cp -r build/PublicRadioPlayer.app /Applications/
```

To launch at login, add it via System Settings > General > Login Items.

## Usage

1. Click the radio icon in the menu bar
2. Select a station and stream
3. Click **Play**
4. Click the **AirPlay button** (top right) to choose your speaker

## CLI

The app runs a small control server on `127.0.0.1:7997` (localhost only). The `prp`
script in this repo is a thin client for it — symlink it onto your `PATH`:

```bash
ln -sf "$PWD/prp" /opt/homebrew/bin/prp
```

```bash
prp status              # play state + current channel
prp list                # all stations and channels
prp play                # start playback
prp pause               # pause
prp toggle              # toggle play/pause
prp switch <channel>    # e.g. prp switch "Radio 4"
prp help                # usage
```

The menu bar app must be running for the CLI to work.

https://github.com/user-attachments/assets/99be6591-1132-45af-bbc5-e4a58c012828

## Stream URLs

### KCRW (Los Angeles)

| Stream | URL |
|--------|-----|
| KCRW 89.9 | `https://streams.kcrw.com/kcrw_mp3` |
| Eclectic24 | `https://streams.kcrw.com/e24_mp3` |
| News24 | `https://streams.kcrw.com/news24_mp3` |

### WNYC (New York City)

| Stream | URL |
|--------|-----|
| WNYC FM 93.9 | `https://fm939.wnyc.org/wnycfm` |
| WNYC AM 820 | `https://am820.wnyc.org/wnycam` |
| New Sounds | `https://q2stream.wqxr.org/q2` |

### Radio France

| Stream | URL |
|--------|-----|
| FIP | `https://icecast.radiofrance.fr/fip-midfi.mp3` |

### BBC

| Stream | URL |
|--------|-----|
| Radio 4 | resolved at launch via [radio-browser](https://www.radio-browser.info) |

BBC rotates the CDN pool numbers in its stream URLs, so Radio 4 is resolved
dynamically at launch (by radio-browser station UUID). The hardcoded URL in the
source is only a fallback.

## Project Structure

```
public-radio-player/
├── PublicRadioPlayer/
│   ├── main.swift            # App entry point
│   ├── AppDelegate.swift     # Menu bar UI, AirPlay picker
│   ├── AudioPlayer.swift     # AVPlayer wrapper, station/stream model
│   └── ControlServer.swift   # Localhost HTTP server for the CLI
├── prp                       # CLI client for the control server
├── build.sh                  # Build script
└── README.md
```

## Troubleshooting

**App doesn't appear in menu bar:**
Check if it's running with `ps aux | grep PublicRadioPlayer`. If not, try running from terminal to see errors:
```bash
./build/PublicRadioPlayer.app/Contents/MacOS/PublicRadioPlayer
```

**AirPlay devices not showing:**
Ensure your AirPlay speakers are on the same network. The picker uses macOS's native AirPlay discovery.

**No audio:**
Click the AirPlay button and verify a device is selected. Check System Settings > Sound to confirm the app isn't muted.
