# WaterGuard Backend API Documentation

## Overview

Complete REST API for the WaterGuard water quality monitoring system with user authentication and sensor management.

---

## 🔐 Authentication Endpoints

### 1. User Registration

**Endpoint:** `POST /api/auth/register`

Register a new user account with email and password.

**Request Body:**

```json
{
  "fullName": "John Doe",
  "email": "john@example.com",
  "password": "SecurePassword123"
}
```

**Response (201 Created):**

```json
{
  "message": "Account created successfully",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "fullName": "John Doe",
    "email": "john@example.com"
  }
}
```

**Status Codes:**

- `201` - User created successfully
- `400` - Missing required fields
- `409` - Email already registered

---

### 2. User Login

**Endpoint:** `POST /api/auth/login`

Authenticate user and get JWT token for subsequent requests.

**Request Body:**

```json
{
  "email": "john@example.com",
  "password": "SecurePassword123"
}
```

**Response (200 OK):**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "fullName": "John Doe",
    "email": "john@example.com"
  }
}
```

**Status Codes:**

- `200` - Login successful
- `400` - Missing email or password
- `401` - Invalid credentials

---

### 3. Get Current User Profile

**Endpoint:** `GET /api/auth/me`

Retrieve the authenticated user's profile information.

**Headers:**

```
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "fullName": "John Doe",
  "email": "john@example.com"
}
```

**Status Codes:**

- `200` - User profile retrieved
- `401` - Missing or invalid token
- `404` - User not found

---

## 📊 Sensor Management Endpoints

### 4. Get All Sensors

**Endpoint:** `GET /api/sensors`

Retrieve list of all water quality sensors with current readings.

**Headers:**

```
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**

```json
[
  {
    "id": "ph-level",
    "name": "pH Level",
    "value": 7.2,
    "unit": "pH",
    "minSafe": 6.5,
    "maxSafe": 8.5,
    "icon": "⚗️",
    "trend": "stable",
    "previousValue": 7.2,
    "updatedAt": "2026-02-24T15:40:10.087Z",
    "status": "safe"
  },
  {
    "id": "turbidity",
    "name": "Turbidity",
    "value": 1.5,
    "unit": "NTU",
    "minSafe": 0,
    "maxSafe": 5,
    "icon": "💧",
    "trend": "down",
    "previousValue": 2,
    "updatedAt": "2026-02-24T15:40:10.087Z",
    "status": "safe"
  },
  {
    "id": "tds",
    "name": "TDS",
    "value": 320,
    "unit": "mg/L",
    "minSafe": 0,
    "maxSafe": 500,
    "icon": "📊",
    "trend": "stable",
    "previousValue": 320,
    "updatedAt": "2026-02-24T15:40:10.087Z",
    "status": "safe"
  },
  {
    "id": "temperature",
    "name": "Temperature",
    "value": 25.3,
    "unit": "°C",
    "minSafe": 15,
    "maxSafe": 30,
    "icon": "🌡️",
    "trend": "up",
    "previousValue": 24.8,
    "updatedAt": "2026-02-24T15:40:10.087Z",
    "status": "safe"
  }
]
```

**Fields:**

- `status` - One of: `safe`, `warning`, `danger`
- `trend` - One of: `up`, `down`, `stable`

**Status Codes:**

- `200` - Sensors retrieved successfully
- `401` - Unauthorized

---

### 5. Get Water Quality Dashboard

**Endpoint:** `GET /api/sensors/dashboard`

Get comprehensive water quality dashboard with summary and all sensors.

**Headers:**

```
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**

```json
{
  "qualityScore": 90,
  "qualityStatus": "Excellent",
  "alertCount": 1,
  "sensors": [
    {
      "id": "ph-level",
      "name": "pH Level",
      "value": 7.2,
      "unit": "pH",
      "minSafe": 6.5,
      "maxSafe": 8.5,
      "icon": "⚗️",
      "trend": "stable",
      "previousValue": 7.2,
      "updatedAt": "2026-02-24T15:40:10.087Z",
      "status": "safe"
    }
    // ... more sensors
  ]
}
```

**Quality Status Mapping:**

- `qualityScore >= 80` → "Excellent"
- `qualityScore >= 60` → "Good"
- `qualityScore >= 40` → "Fair"
- `qualityScore < 40` → "Poor"

**Status Codes:**

- `200` - Dashboard data retrieved
- `401` - Unauthorized

---

### 6. Update Sensor Reading

**Endpoint:** `PATCH /api/sensors/{id}/value`

Update the value of a specific sensor (for testing/manual updates).

**Parameters:**

- `id` - Sensor ID (e.g., "ph-level", "temperature")

**Headers:**

```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Request Body:**

```json
{
  "value": 7.5
}
```

**Response (200 OK):**

```json
{
  "id": "ph-level",
  "name": "pH Level",
  "value": 7.5,
  "unit": "pH",
  "minSafe": 6.5,
  "maxSafe": 8.5,
  "icon": "⚗️",
  "trend": "up",
  "previousValue": 7.2,
  "updatedAt": "2026-02-24T15:42:30.123Z",
  "status": "safe"
}
```

**Status Codes:**

- `200` - Sensor updated successfully
- `400` - Invalid value provided
- `401` - Unauthorized
- `404` - Sensor not found

---

## 🏥 Health Check Endpoints

### 7. Server Health Check

**Endpoint:** `GET /health`

Check if the backend server is running.

**Response (200 OK):**

```json
{
  "ok": true,
  "service": "waterguard-backend"
}
```

---

### 8. Firebase/Firestore Connection Check

**Endpoint:** `GET /health/firebase`

Verify connection to Firebase Firestore database.

**Response (200 OK):**

```json
{
  "ok": true,
  "firestore": true,
  "checkedAt": "2026-02-24T15:40:10.087Z"
}
```

---

## 🔑 Authentication Mechanism

### JWT Token Usage

All protected endpoints require a JWT token in the `Authorization` header:

```
Authorization: Bearer <YOUR_JWT_TOKEN>
```

### Token Expiration

- Default: 7 days
- Configurable via `JWT_EXPIRES_IN` environment variable

### Token Payload

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "fullName": "User Full Name",
  "iat": 1708857610,
  "exp": 1709462410
}
```

---

## 📋 Sensor Parameters

### Available Sensors

| Sensor ID   | Name        | Unit | Min Safe | Max Safe | Icon |
| ----------- | ----------- | ---- | -------- | -------- | ---- |
| ph-level    | pH Level    | pH   | 6.5      | 8.5      | ⚗️   |
| turbidity   | Turbidity   | NTU  | 0        | 5        | 💧   |
| tds         | TDS         | mg/L | 0        | 500      | 📊   |
| temperature | Temperature | °C   | 15       | 30       | 🌡️   |

### Sensor Status Interpretation

- **Safe** ✅: Value within safe range
- **Warning** ⚠️: Value approaching safe boundaries
- **Danger** ❌: Value outside safe range

### Trend Indicators

- **Up** ↗️: Sensor value increasing
- **Down** ↘️: Sensor value decreasing
- **Stable** →: Sensor value unchanged

---

## 🚀 Quick Start

### 1. Register a User

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "John Doe",
    "email": "john@example.com",
    "password": "SecurePassword123"
  }'
```

### 2. Login

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "SecurePassword123"
  }'
```

### 3. Use Token to Access Protected Endpoints

```bash
curl -X GET http://localhost:4000/api/sensors \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## 📝 Error Handling

### Error Response Format

```json
{
  "message": "Error description"
}
```

### Common Error Codes

- `400 Bad Request` - Invalid request parameters
- `401 Unauthorized` - Missing or invalid authentication token
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource already exists (e.g., duplicate email)
- `500 Internal Server Error` - Server-side error

---

## 🔒 Security Notes

1. **Passwords**: Hashed using bcryptjs with 10 salt rounds
2. **Tokens**: Signed JWT tokens with HS256 algorithm
3. **Database**: All data stored in Firebase Firestore
4. **CORS**: Enabled for cross-origin requests
5. **Credentials**: Managed via environment variables

---

## 📦 Technology Stack

- **Runtime**: Node.js v24.13.0
- **Framework**: Express.js v4.21.2
- **Database**: Firebase Cloud Firestore
- **Authentication**: JWT (jsonwebtoken)
- **Password Hashing**: bcryptjs
- **CORS**: cors middleware
- **Async Error Handling**: express-async-errors

---

## 🔧 Configuration

### Environment Variables

```env
PORT=4000
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=service-account@project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----...
```

---

## 📞 Support

For API issues or feature requests, check the backend logs or review the [SECURITY.md](./SECURITY.md) file for credential management guidelines.

---

**API Version:** 1.0.0  
**Last Updated:** 2026-02-24
