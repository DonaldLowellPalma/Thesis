require("dotenv").config();
require("express-async-errors");
const express = require("express");
const cors = require("cors");
const { getFirestore } = require("./firebase");

const authRoutes = require("./routes/auth");
const sensorsRoutes = require("./routes/sensors");
const notificationsRoutes = require("./routes/notifications");
const predictRoutes = require("./routes/predict");
const fcmRoutes = require("./routes/fcm");
const waterQualityRoutes = require("../routes/water-quality");
const deviceConfigRoutes = require("./routes/deviceConfig");
const deviceTokenRoutes = require("./routes/deviceToken");
const { startFirestoreListener } = require("./worker/firestoreListener");

const app = express();
const port = process.env.PORT || 4000;

if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = "dev-only-secret";
}

app.use(cors());
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ ok: true, service: "waterguard-backend" });
});

app.get("/health/firebase", async (req, res) => {
  const nowIso = new Date().toISOString();
  const ref = getFirestore()
    .collection("waterguard_health")
    .doc("connectivity");

  await ref.set({
    lastCheckedAt: nowIso,
    service: "waterguard-backend",
  });

  const snapshot = await ref.get();
  return res.json({
    ok: true,
    firestore: snapshot.exists,
    checkedAt: nowIso,
  });
});

app.use("/api/auth", authRoutes);
app.use("/api/sensors", sensorsRoutes);
app.use("/api/notifications", notificationsRoutes);
app.use("/api/predict", predictRoutes);
app.use("/api/fcm", fcmRoutes);
app.use("/api/water-quality", waterQualityRoutes);
app.use("/api/device/config", deviceConfigRoutes);
app.use("/api/device/token", deviceTokenRoutes);

app.use((err, req, res, next) => {
  console.error(err);
  const statusCode = err.statusCode || 500;
  return res.status(statusCode).json({
    message: err.message || "Internal server error",
  });
});

app.use((req, res) => {
  res.status(404).json({ message: "Not found" });
});

app.listen(port, () => {
  console.log(`WaterGuard backend running on http://localhost:${port}`);
  try {
    startFirestoreListener();
  } catch (err) {
    console.error("Failed to start Firestore listener:", err);
  }
});
