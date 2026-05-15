# minca

A minimalist CalDAV calendar app for Android, Linux, and Windows.

## Features

- CalDAV sync via any compatible server (e.g. Radicale, Nextcloud)
- Create, edit, and delete events — all-day and timed
- Manage multiple calendars: create, delete, and toggle visibility per calendar

## Download

Pre-built binaries are available on the [Releases](https://github.com/t-foerst/minca/releases) page:

| Platform | File |
|----------|------|
| Android  | `minca-android.apk` |
| Linux    | `minca-linux.tar.gz` |
| Windows  | `minca-windows.zip` |

## Setup

1. Install the app for your platform.
2. On first launch, enter your CalDAV server URL, username, and password.
3. Enable one or more calendars from the Settings screen.

The Linux and Windows builds check for updates automatically. When a new version is available, a banner appears at the top of the calendar — click **Jetzt aktualisieren** to download and restart.

## Building from source

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x

```bash
cd flutter_app
flutter pub get

# Android
flutter build apk --release

# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

### Custom app icon

Place a square PNG at `flutter_app/assets/icon/app_icon.png`, then run:

```bash
dart run flutter_launcher_icons
```

## CalDAV server

The app is tested against [Radicale](https://radicale.org). Any CalDAV-compliant server should work.
