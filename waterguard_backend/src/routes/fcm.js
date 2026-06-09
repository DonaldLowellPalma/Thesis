const express = require("express");
const router = express.Router();
const { getFirestore } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

/**
 * Register device FCM token for the authenticated user
 * POST /api/notifications/register-token
 * Body: { fcmToken: "..." }
 */
router.post("/register-token", requireAuth, async (req, res) => {
  const { fcmToken } = req.body;
  const userId = req.user.sub;

  if (!fcmToken) {
    return res.status(400).json({ error: "FCM token is required" });
  }

  try {
    const db = getFirestore();

    // Save token under user's device tokens subcollection
    await db
      .collection("users")
      .doc(userId)
      .collection("deviceTokens")
      .doc(fcmToken)
      .set({
        token: fcmToken,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

    res.json({
      success: true,
      message: "FCM token registered successfully",
    });
  } catch (error) {
    console.error("Error registering FCM token:", error);
    res.status(500).json({ error: "Failed to register FCM token" });
  }
});

/**
 * Unregister device FCM token for the authenticated user
 * POST /api/notifications/unregister-token
 * Body: { fcmToken: "..." }
 */
router.post("/unregister-token", requireAuth, async (req, res) => {
  const { fcmToken } = req.body;
  const userId = req.user.sub;

  if (!fcmToken) {
    return res.status(400).json({ error: "FCM token is required" });
  }

  try {
    const db = getFirestore();

    // Remove token from user's device tokens
    await db
      .collection("users")
      .doc(userId)
      .collection("deviceTokens")
      .doc(fcmToken)
      .delete();

    res.json({
      success: true,
      message: "FCM token unregistered successfully",
    });
  } catch (error) {
    console.error("Error unregistering FCM token:", error);
    res.status(500).json({ error: "Failed to unregister FCM token" });
  }
});

module.exports = router;
