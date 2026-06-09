const nodemailer = require("nodemailer");

function getMailConfig() {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.MAIL_FROM || user;

  if (!host || !user || !pass || !from) {
    return null;
  }

  return {
    host,
    port,
    secure: String(process.env.SMTP_SECURE || "false").toLowerCase() === "true",
    auth: {
      user,
      pass,
    },
    from,
  };
}

function createTransport() {
  const config = getMailConfig();
  if (!config) {
    return null;
  }

  return nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    auth: config.auth,
  });
}

async function sendPasswordChangeEmail({ email, fullName }) {
  const config = getMailConfig();
  if (!config) {
    console.warn(
      "SMTP is not configured. Skipping password change confirmation email.",
    );
    return false;
  }

  const transporter = createTransport();
  const displayName = fullName || "there";

  await transporter.sendMail({
    from: config.from,
    to: email,
    subject: "WaterGuard password changed",
    text: [
      `Hi ${displayName},`,
      "",
      "Your WaterGuard account password was changed successfully.",
      "If you did not make this change, please contact support immediately.",
      "",
      "WaterGuard",
    ].join("\n"),
    html: `
      <p>Hi ${displayName},</p>
      <p>Your WaterGuard account password was changed successfully.</p>
      <p>If you did not make this change, please contact support immediately.</p>
      <p>WaterGuard</p>
    `,
  });

  return true;
}

module.exports = {
  sendPasswordChangeEmail,
};
