# Quick Start Guide - WaterGuard Backend

## ✅ Status

- **Server:** Running on `http://localhost:4000` ✅
- **Database:** Connected to Firebase Firestore ✅
- **All Endpoints:** Operational ✅

---

## 🎯 Available Endpoints

### Authentication (3 endpoints)

```
✅ POST   /api/auth/register     - Register new user
✅ POST   /api/auth/login        - Login & get JWT token
✅ GET    /api/auth/me           - Get user profile (protected)
```

### Sensors (3 endpoints)

```
✅ GET    /api/sensors           - List all 4 sensors (protected)
✅ GET    /api/sensors/dashboard - Water quality dashboard (protected)
✅ PATCH  /api/sensors/{id}/value - Update sensor reading (protected)
```

### Health Checks (2 endpoints)

```
✅ GET    /health                - Server status
✅ GET    /health/firebase       - Database connection
```

---

## 🚀 Quick Test

Run the comprehensive test:

```powershell
cd c:\Users\Severus03\FlutterProjects\waterguard_backend
node final-test.js
```

Expected output: **All tests passing ✅**

---

## 📝 Example Usage

### 1. Register

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "Your Name",
    "email": "your@email.com",
    "password": "YourPassword123"
  }'
```

### 2. Login (Get Token)

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your@email.com",
    "password": "YourPassword123"
  }'
```

Save the `token` from response.

### 3. Get Sensors (Using Token)

```bash
curl -X GET http://localhost:4000/api/sensors \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 4. Get Dashboard

```bash
curl -X GET http://localhost:4000/api/sensors/dashboard \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## 📊 Water Quality Sensors

| Sensor      | ID            | Safe Range   | Current |
| ----------- | ------------- | ------------ | ------- |
| pH Level    | `ph-level`    | 6.5 - 8.5    | 7.2 ✅  |
| Turbidity   | `turbidity`   | 0 - 5 NTU    | 1.5 ✅  |
| TDS         | `tds`         | 0 - 500 mg/L | 320 ✅  |
| Temperature | `temperature` | 15 - 30 °C   | 25.3 ✅ |

---

## 🔑 Authentication

All protected endpoints require:

```
Authorization: Bearer <JWT_TOKEN>
```

Token expires in 7 days.

---

## 💾 Data Storage

All data is stored in:

- **Firebase Cloud Firestore**
- **Region:** asia-southeast1 (Singapore)
- **Status:** Connected ✅

---

## 📁 Important Files

| File                        | Purpose                 |
| --------------------------- | ----------------------- |
| `API_DOCUMENTATION.md`      | Complete API reference  |
| `IMPLEMENTATION_SUMMARY.md` | Implementation details  |
| `SECURITY.md`               | Security procedures     |
| `final-test.js`             | Endpoint testing script |

---

## ⚙️ Configuration

### Environment (.env)

```env
PORT=4000
JWT_SECRET=configured
JWT_EXPIRES_IN=7d
FIREBASE_PROJECT_ID=waterguard-e1a02
```

Location: `c:\Users\Severus03\FlutterProjects\waterguard_backend\.env`

---

## 🛠️ Server Commands

### Start Server

```bash
npm start
```

### Development (Watch Mode)

```bash
npm run dev
```

### Run Tests

```bash
node final-test.js
```

---

## 📊 Current Test Results

```
[✅] Registration - Status 201
[✅] Login - Status 200, Token generated
[✅] Get User - Status 200, Profile retrieved
[✅] Get Sensors - Status 200, 4 sensors
[✅] Dashboard - Status 200, Score: 100/100
[✅] Update Sensor - Status 200, Value updated
```

---

## 🎯 What's Implemented

### ✅ User Registration

- Email validation
- Password hashing (bcryptjs)
- Unique email enforcement

### ✅ User Login

- Credential validation
- JWT token generation
- User profile return

### ✅ Sensor Management

- Real-time sensor readings
- Status calculation (safe/warning/danger)
- Quality scoring
- Trend tracking
- Manual value updates

---

## 🔐 Security Features

- **Passwords:** Hashed with bcryptjs (10 rounds)
- **Tokens:** JWT with 7-day expiration
- **Database:** Firebase Firestore with authentication
- **API:** CORS enabled, error handling
- **Credentials:** .env protected with .gitignore

---

## 📱 Next: Connect to Flutter App

Now that all backend endpoints are ready, you can:

1. Update Flutter app to call these endpoints
2. Store JWT tokens securely in app
3. Use sensor data in UI
4. Display water quality dashboard
5. Add real-time updates (WebSocket ready for future)

---

## 🆘 Troubleshooting

### Port 4000 Already in Use

```bash
Get-Process node | Stop-Process -Force
npm start
```

### Server Won't Start

- Check `.env` file exists
- Verify Firebase credentials
- Run `npm install` if dependencies missing

### Authentication Fails

- Ensure token is in `Authorization: Bearer <token>` format
- Check token hasn't expired
- Verify user was created successfully

### Database Connection Error

- Verify Firebase Firestore is enabled
- Check internet connection
- Verify FIREBASE\_\* env variables

---

## 📞 Files to Reference

1. **API_DOCUMENTATION.md** - Full API docs with all examples
2. **IMPLEMENTATION_SUMMARY.md** - What was built and how
3. **SECURITY.md** - Security best practices
4. **final-test.js** - See working examples

---

## 🎉 Status Summary

```
┌─────────────────────────────────────┐
│  WaterGuard Backend - READY TO SHIP  │
├─────────────────────────────────────┤
│  ✅ All 8 Endpoints Implemented     │
│  ✅ JWT Authentication              │
│  ✅ Firestore Database              │
│  ✅ Water Quality Monitoring        │
│  ✅ All Tests Passing              │
│  ✅ Security Configured             │
│  ✅ Documentation Complete           │
└─────────────────────────────────────┘

Server: http://localhost:4000
Status: RUNNING ✅
```

---

**Ready for Flutter Integration!** 🚀
