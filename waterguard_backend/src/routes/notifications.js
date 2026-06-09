const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { readDb, updateDb } = require("../db");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

router.get("/", requireAuth, async (req, res) => {
  const { severity = "all", archived = "false" } = req.query;
  const showArchived = archived === "true";
  const db = await readDb();

  const notifications = db.notifications
    .filter((n) => (showArchived ? n.isArchived : !n.isArchived))
    .filter((n) => (severity === "all" ? true : n.severity === severity))
    .filter((n) =>
      n.snoozeUntil ? Date.now() >= Date.parse(n.snoozeUntil) : true,
    )
    .sort((a, b) => Date.parse(b.timestamp) - Date.parse(a.timestamp));

  return res.json(notifications);
});

router.get("/stats", requireAuth, async (req, res) => {
  const db = await readDb();

  const stats = {
    total: db.notifications.filter((n) => !n.isArchived).length,
    unread: db.notifications.filter((n) => !n.isRead && !n.isArchived).length,
    danger: db.notifications.filter(
      (n) => n.severity === "danger" && !n.isArchived,
    ).length,
    warning: db.notifications.filter(
      (n) => n.severity === "warning" && !n.isArchived,
    ).length,
    archived: db.notifications.filter((n) => n.isArchived).length,
    snoozed: db.notifications.filter(
      (n) => n.snoozeUntil && Date.now() < Date.parse(n.snoozeUntil),
    ).length,
  };

  return res.json(stats);
});

router.post("/", requireAuth, async (req, res) => {
  const { sensorName, sensorIcon, message, severity = "info" } = req.body;

  if (!sensorName || !sensorIcon || !message) {
    return res
      .status(400)
      .json({ message: "sensorName, sensorIcon and message are required" });
  }

  const notification = {
    id: uuidv4(),
    sensorName,
    sensorIcon,
    message,
    severity,
    timestamp: new Date().toISOString(),
    isRead: false,
    isArchived: false,
    snoozeUntil: null,
  };

  await updateDb((db) => {
    db.notifications.push(notification);
  });

  return res.status(201).json(notification);
});

router.patch("/:id/read", requireAuth, async (req, res) => {
  const { id } = req.params;
  let found = null;

  await updateDb((db) => {
    const notification = db.notifications.find((n) => n.id === id);
    if (!notification) return;
    notification.isRead = true;
    found = notification;
  });

  if (!found) {
    return res.status(404).json({ message: "Notification not found" });
  }

  return res.json(found);
});

router.patch("/mark-all-read", requireAuth, async (req, res) => {
  await updateDb((db) => {
    db.notifications.forEach((n) => {
      if (!n.isArchived) n.isRead = true;
    });
  });

  return res.json({ message: "All non-archived notifications marked as read" });
});

router.patch("/:id/archive", requireAuth, async (req, res) => {
  const { id } = req.params;
  let found = null;

  await updateDb((db) => {
    const notification = db.notifications.find((n) => n.id === id);
    if (!notification) return;
    notification.isArchived = true;
    found = notification;
  });

  if (!found) {
    return res.status(404).json({ message: "Notification not found" });
  }

  return res.json(found);
});

router.patch("/:id/snooze", requireAuth, async (req, res) => {
  const { id } = req.params;
  const { minutes } = req.body;

  if (typeof minutes !== "number" || minutes <= 0) {
    return res
      .status(400)
      .json({ message: "minutes (positive number) is required" });
  }

  let found = null;
  await updateDb((db) => {
    const notification = db.notifications.find((n) => n.id === id);
    if (!notification) return;
    notification.snoozeUntil = new Date(
      Date.now() + minutes * 60_000,
    ).toISOString();
    found = notification;
  });

  if (!found) {
    return res.status(404).json({ message: "Notification not found" });
  }

  return res.json(found);
});

router.delete("/clear", requireAuth, async (req, res) => {
  await updateDb((db) => {
    db.notifications = db.notifications.filter((n) => n.isArchived);
  });

  return res.json({ message: "All non-archived notifications deleted" });
});

module.exports = router;
