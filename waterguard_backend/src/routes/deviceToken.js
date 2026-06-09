const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

// Expected device secret(s) from environment.
// Format: comma-separated list of "deviceId:secret" pairs, or a single shared secret.
// Example: DEVICE_SECRETS="device-001:secret123,device-002:secret456"
// Or simpler: DEVICE_SECRET="shared-secret-for-all-devices"
function getDeviceSecrets() {
  const envSecrets =
    process.env.DEVICE_SECRETS || process.env.DEVICE_SECRET || "";
  const secretsArray = [];

  if (envSecrets.includes(":")) {
    // Format: "device-001:secret123,device-002:secret456"
    envSecrets.split(",").forEach((pair) => {
      const [deviceId, secret] = pair.trim().split(":");
      if (deviceId && secret) {
        secretsArray.push({ deviceId: deviceId.trim(), secret: secret.trim() });
      }
    });
  } else if (envSecrets) {
    // Single shared secret for all devices
    secretsArray.push({ deviceId: null, secret: envSecrets.trim() });
  }

  return secretsArray;
}

// POST /api/device/token
// Request body: { "deviceId": "device-001", "deviceSecret": "secret123" }
// Response: { "ok": true, "token": "...", "expiresIn": 3600 }
router.post("/", async (req, res) => {
  try {
    const { deviceId, deviceSecret } = req.body;

    if (!deviceId || !deviceSecret) {
      return res.status(400).json({
        ok: false,
        message: "deviceId and deviceSecret required",
      });
    }

    const deviceSecrets = getDeviceSecrets();
    if (deviceSecrets.length === 0) {
      console.error("No device secrets configured in environment");
      return res.status(500).json({
        ok: false,
        message: "Server not configured for device tokens",
      });
    }

    // Validate the secret
    let secretValid = false;
    for (const entry of deviceSecrets) {
      if (entry.deviceId === null) {
        // Shared secret for all devices
        if (deviceSecret === entry.secret) {
          secretValid = true;
          break;
        }
      } else {
        // Per-device secret
        if (entry.deviceId === deviceId && deviceSecret === entry.secret) {
          secretValid = true;
          break;
        }
      }
    }

    if (!secretValid) {
      console.warn(`Invalid device token request for deviceId: ${deviceId}`);
      return res.status(401).json({
        ok: false,
        message: "Invalid device credentials",
      });
    }

    // Create a custom Firebase token valid for 1 hour
    const expiresIn = 3600; // 1 hour in seconds
    const customToken = await admin.auth().createCustomToken(deviceId, {
      // Optional claims
      isDevice: true,
    });

    return res.json({
      ok: true,
      token: customToken,
      expiresIn,
    });
  } catch (err) {
    console.error("Error creating device token:", err);
    return res.status(500).json({
      ok: false,
      message: "Failed to create token",
    });
  }
});

module.exports = router;
