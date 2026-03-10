# Slack Custom Sound

Minimal macOS menu bar app that watches Notification Center banners via Accessibility
and plays one custom sound for Slack notifications.

## Features

- Menu bar app with no Dock icon
- One custom sound for all Slack notifications
- Choose sound file
- Play test sound
- Enable or disable monitoring
- Request Accessibility permission
- Automatically re-checks Accessibility permission without app restart
- Launch at login toggle
- Dedup by AXIdentifier with 5 minute TTL
- Build script for a `.app` bundle

## Quick Start

### 1. Clone the repository

    git clone <repo-url>
    cd SlackCustomSound

### 2. Build the app bundle

    chmod +x build-app.sh
    ./build-app.sh

This will produce:

    dist/Slack Custom Sound.app

### 3. Launch the app

    open "dist/Slack Custom Sound.app"

After launching, a **menu bar icon** (bell) will appear.

---

## Initial Setup

### 1. Grant Accessibility permission

Click **Request Accessibility Access** from the menu bar.

macOS will open:

System Settings → Privacy & Security → Accessibility

Add **Slack Custom Sound** to the list and enable the toggle.

The app will detect the permission automatically — **no restart required**.

---

### 2. Choose a notification sound

Click **Choose Sound…** in the menu bar.

Select any audio file:

- `.mp3`
- `.wav`
- `.m4a`

You can test the sound using **Play Test Sound**.

---

### 3. Enable monitoring

Make sure **Enable monitoring** is turned on.

The status should show:

Monitoring Slack notifications

---

### 4. (Optional) Launch automatically on login

Enable **Launch at login** if you want the app to start automatically when macOS starts.


## Development mode (optional)

You can also run the raw binary without creating the bundle:

    swift build -c release
    .build/release/SlackCustomSound

## Run from Xcode

Open the package in Xcode and run the `SlackCustomSound` target.

## Build from terminal

```bash
swift build -c release
.build/release/SlackCustomSound
```

## Build a .app bundle

```bash
chmod +x build-app.sh
./build-app.sh
open "dist/Slack Custom Sound.app"
```

## Notes

- Accessibility permission still must be granted manually by the user.
- Launch at login works best when running as a real `.app` bundle.
