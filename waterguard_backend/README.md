# WaterGuard Backend

Standalone backend for your Flutter app, located outside `my_app`.

## Location

`c:\Users\Severus03\FlutterProjects\waterguard_backend`

## Setup

1. Open a terminal in this folder.
2. Copy env file:
   - PowerShell: `Copy-Item .env.example .env`
3. Add Firebase credentials to `.env`:
   - Get from Firebase Console > Project Settings > Service Accounts > Generate Key
   - Add these values from the downloaded JSON:
     - `FIREBASE_PROJECT_ID`
     - `FIREBASE_CLIENT_EMAIL`
     - `FIREBASE_PRIVATE_KEY` (wrap in quotes, preserve `\n`)

4. Configure SMTP if you want password-change emails:

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_SECURE`
- `SMTP_USER`
- `SMTP_PASS`
- `MAIL_FROM`

⚠️ **SECURITY**: Never commit `.env` to git. See [SECURITY.md](./SECURITY.md) for details.

5. Install dependencies:
   - `npm install`
6. Start server:
   - `npm run dev` (auto-restart)
   - or `npm start`

Server runs on `http://localhost:4000` by default.

## API Endpoints

### Health

- `GET /health`

### Auth

- `POST /api/auth/signup`
  - body: `{ "fullName": "Name", "email": "user@mail.com", "password": "secret" }`
- `POST /api/auth/login`
  - body: `{ "email": "user@mail.com", "password": "secret" }`
- `GET /api/auth/me` (Bearer token required)

### Sensors

- `GET /api/sensors` (Bearer token required)
- `GET /api/sensors/dashboard` (Bearer token required)
- `PATCH /api/sensors/:id/value` (Bearer token required)
  - body: `{ "value": 7.4 }`
- `POST /api/sensors/ingest` (ESP32 ingest, optional `x-ingest-key`)
  - body: `{ "rawTurbidity": 2345, "rawTds": 1987, "rawPh": 1764, "temperature": 26.4, "ph7Voltage": 2.075, "phSlope": -0.059, "turbClearVoltage": 1.6, "turbDirtyVoltage": 0.6, "tdsScaleFactor": 1.0, "tdsTempCoeff": 0.02 }`
  - The backend converts the raw ADC readings into calibrated turbidity, TDS, and pH values before saving them.

### Prediction

- `POST /api/predict`
  - body: `{ "turbidity": 12.3, "tds": 210, "phLevel": 7.1, "temperature": 26.4 }`
  - The backend calls the Python predictor in `src/ml/predict.py`.
  - If `src/ml/model.pkl` is present, the predictor uses the Random Forest model.
  - If the model is unavailable, the predictor falls back to rule-based classification.

### Notifications

- `GET /api/notifications?severity=all&archived=false` (Bearer token required)
- `GET /api/notifications/stats` (Bearer token required)
- `POST /api/notifications` (Bearer token required)
- `PATCH /api/notifications/:id/read` (Bearer token required)
- `PATCH /api/notifications/mark-all-read` (Bearer token required)
- `PATCH /api/notifications/:id/archive` (Bearer token required)
- `PATCH /api/notifications/:id/snooze` (Bearer token required, body: `{ "minutes": 60 }`)
- `DELETE /api/notifications/clear` (Bearer token required)

## Notes

- Data is stored in Firebase Firestore (`waterguard/state` document).
- Live ESP32 ingestion can write through backend relay (`POST /api/sensors/ingest`) into Firestore (`waterguard/esp32_live`).
- ESP32 devices send raw analog readings and calibration constants; the backend recalculates the water-quality values before persisting them.
- Sensor APIs (`/api/sensors`, `/api/sensors/dashboard`) overlay `esp32_live` values before returning data to the frontend.
- The prediction pipeline uses a Random Forest model when `src/ml/model.pkl` is available.
- Starter sensor + notification data is auto-seeded on first run if empty.
- Replace `JWT_SECRET` in `.env` before production use.
- Password-change confirmation emails are sent only when SMTP variables are configured.
- For relay security, set `ESP32_INGEST_KEY` in `.env` and send same value in header `x-ingest-key`.
