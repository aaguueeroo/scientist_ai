# Marie Query — Flutter app

This folder contains the **Marie Query** client (Flutter). It talks to the AI Scientist **backend** over HTTP. Run the backend first if you are using a real API (see the repository root [README.md](../README.md)).

## Install Flutter

You need a working **Flutter SDK** on your machine before you can run this app. Follow the official install guide for your platform:

- **[Install Flutter](https://docs.flutter.dev/get-started/install)**

After installation, run:

```bash
flutter doctor
```

Fix any items reported there (Xcode for iOS/macOS, Android toolchain, etc.) as needed for the platforms you care about.

## Run the app (basic)

From this directory:

```bash
cd frontend
flutter pub get
flutter run
```

`flutter run` will list available devices; pick a simulator, emulator, or connected device. To hit a **local** backend, pass the API base URL (default backend port in this repo is **8000**):

```bash
flutter run --dart-define=SCIENTIST_API_BASE_URL=http://127.0.0.1:8000
```

If you omit `SCIENTIST_API_BASE_URL`, the app uses a built-in mock client (no real server required).

**Further reading:** [Get started with Flutter](https://docs.flutter.dev/get-started/learn-flutter) and the full [Flutter documentation](https://docs.flutter.dev/).

## Run on desktop (macOS, Windows, or Linux)

Desktop support is documented here:

- **[Build and release a desktop app](https://docs.flutter.dev/platform-integration/desktop)**

Typical flow:

1. **Enable the desktop target** (only needed once per machine; skip if your `flutter config` already shows it enabled):

   ```bash
   # macOS
   flutter config --enable-macos-desktop
   # Windows
   flutter config --enable-windows-desktop
   # Linux
   flutter config --enable-linux-desktop
   ```

2. **Install extra tooling** the platform needs (C++ build tools, Visual Studio on Windows, Linux desktop libraries, etc.); `flutter doctor` will list what is missing.

3. **Run** from `frontend/`:

   ```bash
   flutter pub get
   flutter run -d macos      # or windows / linux
   ```

   With a local API:

   ```bash
   flutter run -d macos --dart-define=SCIENTIST_API_BASE_URL=http://127.0.0.1:8000
   ```

4. **Optional:** [Create a release build](https://docs.flutter.dev/deployment/macos) for the desktop platform you use (e.g. `flutter build macos`).

## Official documentation

- **Install & setup:** [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
- **All docs (tutorials, API reference, troubleshooting):** [https://docs.flutter.dev/](https://docs.flutter.dev/)
- **Desktop apps:** [https://docs.flutter.dev/platform-integration/desktop](https://docs.flutter.dev/platform-integration/desktop)
