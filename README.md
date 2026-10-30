# pinepal_mobile
PinePal Mobile: an offline-first Flutter app that lets farmers detect pineapple diseases and disorders on the spot. It runs on-device MobileNetV2 classification from the phone camera with no internet needed, stores scans locally, and syncs them to the Flask + MySQL backend.

This is the phone app of PinePal. The [PinePal web dashboard](https://github.com/ethanbueno/pinepal_web) (React) and the Flask backend are in a separate repository; officers use the dashboard to follow the scans that farmers sync from here.

## Features

- **Scanner:** take a photo with the camera (with a framing guide, a light toggle and camera flip) or pick one from the gallery. The model runs on the phone and shows the disease, the confidence and the three most likely classes.
- **Six classes:** Crown Rot, Fruit Rot, Mealybug Wilt, Fruit Fasciation, Multiple Crown and No Disease.
- **Diagnostic report:** severity, location, farm and municipality, a description, what to look for, numbered remediation steps and prevention.
- **Guide:** the same information for every disease, available offline.
- **History:** every scan with its sync status and feedback, the model's accuracy on the scans that were checked, CSV export and delete.
- **Farmer feedback:** the farmer says whether a result was correct or wrong (and what it really was, if known). This is a flag for later review, not a verified diagnosis; officers verify scans on the web.
- **Account:** sign in with the same account as the web dashboard, or create a farmer account. Scanning never needs an account.
- **Sync:** scans are uploaded with their photos, manually with **Sync now** or automatically (on Wi-Fi only by default). A scan is marked synced only after the server accepts it, and editing a synced scan sends it again.
- **Farm details:** the farm name and municipality are saved on every new scan so the dashboard can place it on its map and filters.
- **Design:** follows the web dashboard: the same colors, Geist typeface, disease colors and wording, with light and dark mode.

## Screens

| Tab | What it is |
| --- | --- |
| Home | Latest scans and the scan button |
| History | All scans, status chips, export |
| Scan (camera button) | Camera, gallery, photo preview and result |
| Guide | Disease information |
| Profile | Account, my farm, sync status. The gear opens Settings (sync mode, dark mode, about) |

## Getting started

You need [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.12 or newer) and an Android emulator or phone.

```
flutter pub get
flutter run
```

The app works fully offline without a server: scanning, history, the guide and feedback never need one. A server is only needed to sign in and sync.

### Connecting to the backend

The server address is part of the app, not a setting for farmers. Choose it when you build:

```
flutter run --dart-define=PINEPAL_API_URL=https://your-server
```

Without it the app uses `http://10.0.2.2:5000`, which is how the Android emulator reaches a backend running on the same computer.

- **Debug builds** may use plain `http://`. **Release builds need `https://`.**
- **On a real phone** use your computer's address on the local network (for example `http://192.168.x.x:5000`) in the build option above.
- **For developers:** tap the version number in Settings seven times to show a Developer section where the address can be changed or tested without rebuilding.

The backend setup (database, accounts, routes) is described in the web project's README.

## Project layout

```
lib/
  main.dart            starts the app, loads the saved settings and account
  screens/             one file per screen (scanner, history, profile, settings, ...)
  widgets/             shared pieces (cards, scanner controls, disease badge, ...)
  services/            classifier, local database, sync, API client, account, settings
  models/              scan record and disease guide data
  theme/               colors, theme and light/dark mode (the web design tokens)
  utils/               formatting and the list of municipalities
assets/
  models/              the MobileNetV2 model and its labels
  data/                the disease guide (remediation protocols)
  fonts/, icons/       Geist typeface and the logo
test/                  automated tests
```

## Tests

```
flutter analyze
flutter test
```

The tests cover the local database and its upgrades, the CSV export, the API client and sync logic (against a fake server), sign-in and settings, and the main widgets.

## Privacy and security

- Scans, photos and GPS locations are stored on the phone and leave it only when the farmer signs in and syncs.
- The sign-in token is kept in the phone's secure storage (Android Keystore / iOS Keychain).
- No passwords, keys or server details are stored in this repository.

## Known limitations

- There is no check yet that a photo actually shows a pineapple; any photo is classified as one of the six classes.
- Officer verification is done on the web, not in this app.
- Deleting a scan on the phone does not delete it from the server.
- Tested on the Android emulator; testing on real phones is still to do.
