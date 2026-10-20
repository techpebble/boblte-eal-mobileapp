# EAL Track

Flutter Android app for EAL issuance, production entry, and dispatch scanning.
This repository currently includes the Android platform project.

## Backend compatibility

The app uses the EAL API at `https://boblte-eal-api.techpebble.com/api/v1/`.
Login is configured in `lib/services/authService.dart`; authenticated requests
are configured in `lib/services/dioClient.dart`.

- Item responses support both plain company/pack IDs and populated objects.
  Production submissions continue to send the IDs required by the backend.
- Production selection requests `items?isActive=true`, excludes inactive items,
  and refreshes before opening the picker. Items without a status remain active
  for compatibility with older data.
- Authenticated requests read the current session token on every request.
- Android internet permission is declared for release builds as well as development.

## Development and verification

```sh
flutter pub get
flutter test
flutter analyze
flutter build apk --release
```

Tests use local API fixtures and temporary session storage; they do not contact
the production API. They cover item parsing, active item selection, session
changes, and the signed-out login screen.

Before rollout, verify login, production submission, and dispatch scanning on a
device against the target backend. Android release builds currently use the
project's debug signing configuration; distribution signing must be configured
separately.
