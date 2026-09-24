# SmartPay Device Lock

Flutter/Android client for SmartPay EMI device monitoring and lock-status polling.

## Backend

Default APK API base URL:

```text
https://api.smartpay.click/apk
```

The customer lock app should call only:

```text
POST /apk/devices/track
GET  /apk/devices/:imei/lock-status
```

Do not call `/apk/management/enterprise` from this customer app. Enterprise setup is an admin/backend flow.

## Build Config

Normal debug run:

```bash
flutter run
```

Override the API base URL for Dart calls:

```bash
flutter run --dart-define=SMART_PAY_APK_API_BASE_URL=https://api.smartpay.click/apk
```

If the backend enables `DEVICE_TRACK_KEY`, pass it to Dart and also make it available to Android native `BuildConfig`.
For local development, prefer putting this in your user-level Gradle properties, not in Git:

```properties
deviceTrackKey=<device-track-key>
smartPayApkApiBaseUrl=https://api.smartpay.click/apk
```

Then run Flutter with the same Dart define:

```bash
flutter run --dart-define=DEVICE_TRACK_KEY=<device-track-key>
```
