# macOS Virtual Display & Sunshine Controller

A unified macOS Menu Bar application that creates a minimalist virtual display (dummy display) and manages LizardByte's Sunshine streaming server, optimized for low-latency, high-refresh-rate streaming to clients like Moonlight.

## Features

- **Virtual Display Creation**: Instantiates a virtual screen (up to 5120x3200) with proper Retina (HiDPI) scaling support and multiple refresh rates (**60Hz, 90Hz, and 120Hz**).
- **Frame Pacing (Anti-Throttling)**: Implements `CVDisplayLink` to force constant frame rendering on the headless display, bypassing macOS's aggressive window server frame throttling.
- **Detached Sunshine Execution**: Bypasses macOS Sequoia's screen recording permission loops. By running Sunshine as a detached `LaunchAgent`, permission is attributed directly to the `sunshine` binary (already approved) rather than the wrapper app.
- **Auto-Configuring LaunchAgent**: Automatically generates the required LaunchAgent plist configuration locally using the active user's home path on app launch. No manual file copying required.
- **Unified Menu Bar Control**: Start/stop the virtual display and Sunshine independently or exit both from a single dropdown icon (`🖥️`).
- **Wi-Fi Optimization Utility**: Includes a script to temporarily disable AWDL (`awdl0` interface) to resolve background AirDrop scanning packet drops.

---

## Project Structure

- `menu_app.swift`: The Swift source code for the Menu Bar GUI application.
- `main.swift`: CLI version of the virtual display utility.
- `DummyDisplay-Bridging-Header.h`: Exposes private CoreGraphics APIs (`CGVirtualDisplay`) to Swift.
- `toggle_awdl.sh`: Helper script to toggle AWDL down/up.
- `Info.plist`: Application package configuration.

---

## Setup & Installation

### 1. Build the App Bundle

To package this as a standard macOS `.app` bundle:

```bash
# Recreate the bundle directory structure
mkdir -p DummyDisplay.app/Contents/MacOS

# Copy Info.plist into the bundle
cp Info.plist DummyDisplay.app/Contents/

# Compile the binary
swiftc menu_app.swift \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics -framework Foundation -framework CoreVideo -framework AppKit \
  -o DummyDisplay.app/Contents/MacOS/dummy_display_menu

# Sign the app locally to ensure stable macOS TCC registration
codesign --force --deep --sign - DummyDisplay.app
```

Move `DummyDisplay.app` to your `/Applications` directory.

### 2. Screen Recording Permissions

To allow Sunshine to capture the screen without permission prompts:
- Open **System Settings > Privacy & Security > Screen & System Audio Recording**.
- Click the `+` button and add the **real path** of the Sunshine binary (resolving the Homebrew symlink):
  `/opt/homebrew/Cellar/sunshine/<version>/bin/sunshine`
- Ensure it is checked/enabled.

---

## Usage

1. Launch **`DummyDisplay`** from your Applications folder.
2. Click the monitor icon `🖥️` in your macOS Menu Bar:
   - Click **Enable Virtual Display**.
   - Click **Start Sunshine**.
3. Connect your tablet/client device via **Moonlight** using the appropriate IP (e.g., `10.0.2.2` if tethered via USB and `gnirehtet` is running, or your Mac's network IP).
4. If your client supports high refresh rates (like 90Hz or 120Hz), select the desired refresh rate in Moonlight or macOS display preferences.

### Wi-Fi Latency Optimization
If you stream over Wi-Fi and experience periodic stuttering, disable background AirDrop scanning:
```bash
sudo ./toggle_awdl.sh down
```
To enable it back later:
```bash
sudo ./toggle_awdl.sh up
```

## License
MIT
