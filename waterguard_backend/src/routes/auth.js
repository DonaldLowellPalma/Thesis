const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");
const {
  addUser,
  getUserByEmail,
  getUserById,
  setPasswordResetToken,
  updateUserPassword,
} = require("../db");
const { sendPasswordChangeEmail } = require("../email");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

router.post("/register", async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    if (!fullName || !email || !password) {
      return res
        .status(400)
        .json({ message: "fullName, email, and password are required" });
    }

    const normalizedEmail = String(email).toLowerCase().trim();
    const existing = await getUserByEmail(normalizedEmail);

    if (existing) {
      return res.status(409).json({ message: "Email already registered" });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = {
      id: uuidv4(),
      fullName,
      email: normalizedEmail,
      passwordHash,
      createdAt: new Date().toISOString(),
    };

    await addUser(user);

    return res.status(201).json({
      message: "Account created successfully",
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Register error:", error.message);
    return res.status(500).json({ message: `Server error: ${error.message}` });
  }
});

router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: "email and password are required" });
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const user = await getUserByEmail(normalizedEmail);

  if (!user) {
    return res.status(401).json({ message: "Invalid email or password" });
  }

  const matches = await bcrypt.compare(password, user.passwordHash);
  if (!matches) {
    return res.status(401).json({ message: "Invalid email or password" });
  }

  const token = jwt.sign(
    { sub: user.id, email: user.email, fullName: user.fullName },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "7d" },
  );

  return res.json({
    token,
    user: {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
    },
  });
});

router.post("/forgot-password", async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ message: "email is required" });
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const user = await getUserByEmail(normalizedEmail);

  if (!user) {
    return res.json({
      message: "If the account exists, a reset token has been generated.",
    });
  }

  const rawResetToken = crypto.randomBytes(24).toString("hex");
  const resetTokenHash = crypto
    .createHash("sha256")
    .update(rawResetToken)
    .digest("hex");
  const expiresAt = new Date(Date.now() + 15 * 60_000).toISOString();

  await setPasswordResetToken(user.id, resetTokenHash, expiresAt);

  return res.json({
    message: "Reset token generated.",
    resetToken: rawResetToken,
    expiresAt,
  });
});

router.post("/reset-password", async (req, res) => {
  const { email, resetToken, newPassword } = req.body;

  if (!email || !resetToken || !newPassword) {
    return res
      .status(400)
      .json({ message: "email, resetToken, and newPassword are required" });
  }

  if (String(newPassword).length < 6) {
    return res
      .status(400)
      .json({ message: "newPassword must be at least 6 characters" });
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const user = await getUserByEmail(normalizedEmail);

  if (
    !user ||
    !user.passwordResetTokenHash ||
    !user.passwordResetTokenExpiresAt
  ) {
    return res.status(400).json({ message: "Invalid or expired reset token" });
  }

  if (Date.parse(user.passwordResetTokenExpiresAt) < Date.now()) {
    return res.status(400).json({ message: "Invalid or expired reset token" });
  }

  const incomingTokenHash = crypto
    .createHash("sha256")
    .update(String(resetToken))
    .digest("hex");

  if (incomingTokenHash !== user.passwordResetTokenHash) {
    return res.status(400).json({ message: "Invalid or expired reset token" });
  }

  const passwordHash = await bcrypt.hash(String(newPassword), 10);
  await updateUserPassword(user.id, passwordHash);

  let emailSent = false;
  try {
    emailSent = await sendPasswordChangeEmail({
      email: user.email,
      fullName: user.fullName,
    });
  } catch (error) {
    console.error("Password change email error:", error.message);
  }

  return res.json({
    message: "Password reset successful",
    emailSent,
  });
});

router.get("/me", requireAuth, async (req, res) => {
  const user = await getUserById(req.user.sub);

  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  return res.json({
    id: user.id,
    fullName: user.fullName,
    email: user.email,
  });
});

module.exports = router;
