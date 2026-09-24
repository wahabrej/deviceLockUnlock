# Enrollment API Contract

The Flutter app never receives or stores a Google service-account key. The backend owns Android Management API authentication.

## Create enterprise

`POST /apk/management/enterprise`

This is an admin/backend setup call. The customer lock app must not call it on app startup. It requires an authenticated Smart Pay admin token with enterprise-management permission.

Request:

```json
{
  "enterpriseDisplayName": "Smart Pay"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "state": "SIGNUP_REQUIRED",
    "signupUrlName": "signupUrls/example",
    "signupUrl": "https://enterprise.google.com/signup/android/email?..."
  }
}
```

After the admin completes the Google signup form, Google redirects to the backend callback with `enterpriseToken`. The backend then calls `enterprises.create` and stores the final `enterpriseName`.

## Create enrollment token

`POST /apk/management/enrollment-token`

This is for the seller/admin app that renders the QR code. It also requires a Smart Pay Bearer token. The customer lock app should only call device tracking and lock-status endpoints after it is installed/enrolled.

Request:

```json
{
  "imei": "123456789012345",
  "customerId": "optional-customer-id",
  "loanId": "optional-loan-id"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "qrCode": "{\"android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME\":\"...\"}"
  }
}
```

The `qrCode` value is the raw provisioning payload returned by Android Management API. Flutter renders it; it must not be replaced with a screenshot URL.

Both endpoints must return a non-2xx response with a JSON error when creation fails. The backend must store the service-account key in server-side secret storage only.
