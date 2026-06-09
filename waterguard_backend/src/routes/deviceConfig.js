const express = require("express");
const router = express.Router();

// Returns project-level config useful for devices during provisioning.
router.get("/", async (req, res) => {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID || null;
    const accessToken = process.env.FIRESTORE_ACCESS_TOKEN || null;

    return res.json({
      ok: true,
      projectId,
      accessToken,
    });
  } catch (err) {
    console.error("Error returning device config", err);
    return res.status(500).json({ ok: false, message: "internal error" });
  }
});

module.exports = router;
