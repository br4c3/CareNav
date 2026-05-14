# CareNav

Flutter app with guest-first, elderly-friendly navigation and optional Firebase
authentication.

## Features

- Guest users can open the app and use navigation immediately.
- View destinations and routes on an interactive OpenStreetMap map.
- Search one destination at a time, then start guidance.
- Prefer elevator routes, fall back to escalators, and avoid stairs unless there
  is no alternative.
- Use GPS as the starting point, with manual origin correction when GPS is
  unavailable or inaccurate indoors.
- Combine an outdoor route segment with an indoor facility route segment.
- Firebase Email/Password auth can be enabled later without blocking guest use.

The current map uses public OpenStreetMap raster tiles through `flutter_map`.
For production traffic, configure a tile provider that matches your usage and
rate-limit requirements.

## Routing setup

Outdoor routing uses openrouteservice when an API key is provided:

```sh
flutter run --dart-define=ORS_API_KEY=your_openrouteservice_key
```

If the key is missing or the API request fails, the app displays a safe fallback
route so navigation remains usable during development.

Indoor route data is loaded from Firestore when Firebase is configured. The app
expects `facilities/default` with `entryNodeId`, plus `nodes`, `edges`, and
`destinations` subcollections. Edge `type` values are `walkway`, `elevator`,
`escalator`, `stairs`, `ramp`, or `outdoor`. Without Firebase data, the app uses
the built-in sample facility graph.

## Firebase setup

This code can run without Firebase configuration. If Firebase project files are
missing, the app falls back to a local guest/auth mode so development can
continue.

1. Install the FlutterFire CLI.
2. Run `flutterfire configure` from this directory.
3. Enable Email/Password sign-in in Firebase Authentication.
4. Run the app with `flutter run`.

## Verification

```sh
flutter test
flutter analyze
```
