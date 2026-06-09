# my_app

A new Flutter project.

## Backend URL Configuration

The app now supports environment-based backend URLs.

- Local web fallback: `http://localhost:4000`
- Android emulator fallback: `http://10.0.2.2:4000`
- Production/deployed build: pass `API_BASE_URL` with `--dart-define`

Examples:

```bash
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com
```

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Use an HTTPS public domain for deployed APKs.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
