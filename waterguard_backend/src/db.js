const { getFirestore } = require("./firebase");

const USERS_COLLECTION = "users";
const SENSORS_COLLECTION = "sensor_data";
const READINGS_COLLECTION = "sensor_readings";
const STATE_COLLECTION = "waterguard";
const STATE_DOCUMENT = "state";
const ESP32_LIVE_DOCUMENT = "esp32_live";

function getDefaultSensors() {
  return [
    {
      id: "ph-level",
      name: "pH Level",
      value: 7.2,
      unit: "pH",
      minSafe: 6.5,
      maxSafe: 8.5,
      icon: "⚗️",
      trend: "stable",
      previousValue: 7.2,
      updatedAt: new Date().toISOString(),
    },
    {
      id: "turbidity",
      name: "Turbidity",
      value: 1.5,
      unit: "NTU",
      minSafe: 0,
      maxSafe: 5,
      icon: "💧",
      trend: "down",
      previousValue: 2,
      updatedAt: new Date().toISOString(),
    },
    {
      id: "tds",
      name: "TDS",
      value: 320,
      unit: "mg/L",
      minSafe: 0,
      maxSafe: 500,
      icon: "📊",
      trend: "stable",
      previousValue: 320,
      updatedAt: new Date().toISOString(),
    },
    {
      id: "temperature",
      name: "Temperature",
      value: 25.3,
      unit: "°C",
      minSafe: 15,
      maxSafe: 30,
      icon: "🌡️",
      trend: "up",
      previousValue: 24.8,
      updatedAt: new Date().toISOString(),
    },
  ];
}

function getDefaultDb() {
  return {
    users: [],
    sensors: getDefaultSensors(),
    notifications: [
      {
        id: "n1",
        sensorName: "pH Level",
        sensorIcon: "⚗️",
        message: "pH is at 7.2 - Perfect balance for water quality",
        severity: "info",
        timestamp: new Date(Date.now() - 5 * 60_000).toISOString(),
        isRead: true,
        isArchived: false,
        snoozeUntil: null,
      },
      {
        id: "n2",
        sensorName: "Temperature",
        sensorIcon: "🌡️",
        message: "Temperature increased to 25.3°C - Monitor change",
        severity: "warning",
        timestamp: new Date(Date.now() - 2 * 60 * 60_000).toISOString(),
        isRead: false,
        isArchived: false,
        snoozeUntil: null,
      },
    ],
  };
}

function normalizeDb(db) {
  return {
    users: Array.isArray(db?.users) ? db.users : [],
    sensors: Array.isArray(db?.sensors) ? db.sensors : getDefaultSensors(),
    notifications: Array.isArray(db?.notifications)
      ? db.notifications
      : getDefaultDb().notifications,
  };
}

// User Collection Operations
async function getUserByEmail(email) {
  const firestore = getFirestore();
  const normalizedEmail = String(email).toLowerCase().trim();
  const snapshot = await firestore
    .collection(USERS_COLLECTION)
    .where("email", "==", normalizedEmail)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return {
    id: doc.id,
    ...doc.data(),
  };
}

async function getUserById(userId) {
  const firestore = getFirestore();
  const snapshot = await firestore
    .collection(USERS_COLLECTION)
    .doc(userId)
    .get();

  if (!snapshot.exists) {
    return null;
  }

  return snapshot.data();
}

async function addUser(user) {
  const firestore = getFirestore();
  await firestore.collection(USERS_COLLECTION).doc(user.id).set(user);
  return user;
}

async function setPasswordResetToken(userId, tokenHash, expiresAt) {
  const firestore = getFirestore();
  await firestore.collection(USERS_COLLECTION).doc(userId).update({
    passwordResetTokenHash: tokenHash,
    passwordResetTokenExpiresAt: expiresAt,
  });
}

async function updateUserPassword(userId, passwordHash) {
  const firestore = getFirestore();
  await firestore.collection(USERS_COLLECTION).doc(userId).update({
    passwordHash,
    passwordResetTokenHash: null,
    passwordResetTokenExpiresAt: null,
    passwordUpdatedAt: new Date().toISOString(),
  });
}

async function readDb() {
  const stateRef = await ensureDb();
  const snapshot = await stateRef.get();
  return normalizeDb(snapshot.data());
}

async function updateDb(mutator) {
  const firestore = getFirestore();
  const stateRef = firestore.collection(STATE_COLLECTION).doc(STATE_DOCUMENT);

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(stateRef);
    const db = snapshot.exists ? normalizeDb(snapshot.data()) : getDefaultDb();

    const result = await mutator(db);
    transaction.set(stateRef, db);
    return result;
  });
}

// Sensor Collection Operations
async function readSensors() {
  const firestore = getFirestore();
  const snapshot = await firestore.collection(SENSORS_COLLECTION).get();

  if (snapshot.empty) {
    // Initialize with default sensors if collection is empty
    const defaultSensors = getDefaultSensors();
    for (const sensor of defaultSensors) {
      await firestore.collection(SENSORS_COLLECTION).doc(sensor.id).set(sensor);
    }
    return defaultSensors;
  }

  return snapshot.docs.map((doc) => doc.data());
}

async function updateSensor(sensorId, updates) {
  const firestore = getFirestore();
  const sensorRef = firestore.collection(SENSORS_COLLECTION).doc(sensorId);

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sensorRef);
    if (!snapshot.exists) {
      throw new Error(`Sensor ${sensorId} not found`);
    }

    const updatedSensor = {
      ...snapshot.data(),
      ...updates,
    };

    transaction.update(sensorRef, updates);
    return updatedSensor;
  });
}

async function ensureDb() {
  const firestore = getFirestore();
  const stateRef = firestore.collection(STATE_COLLECTION).doc(STATE_DOCUMENT);

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(stateRef);
    if (!snapshot.exists) {
      transaction.set(stateRef, getDefaultDb());
    }
  });

  return stateRef;
}

function toFiniteNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return null;
}

function adcToVoltage(rawAdc) {
  return (rawAdc * 3.3) / 4095;
}

function calculateNTU(voltage, clearVoltage = 1.6, dirtyVoltage = 0.6) {
  let vClear = clearVoltage;
  let vDirty = dirtyVoltage;

  if (vClear <= vDirty + 0.05) {
    vClear = 1.6;
    vDirty = 0.6;
  }

  if (voltage >= vClear - 0.02) {
    return 0;
  }

  if (voltage <= vDirty + 0.02) {
    return 3000;
  }

  const input = Math.trunc(voltage * 1000);
  const inMin = Math.trunc(vDirty * 1000);
  const inMax = Math.trunc(vClear * 1000);
  if (inMax === inMin) {
    return 0;
  }

  const mapped = ((input - inMin) * (0 - 3000)) / (inMax - inMin) + 3000;
  return Math.trunc(Math.min(3000, Math.max(0, mapped)));
}

function calculateTDS(
  voltage,
  temperatureC,
  tdsScaleFactor = 1,
  tdsTempCoeff = 0.02,
) {
  let tempForComp = temperatureC;
  if (tempForComp < -20 || tempForComp > 125) {
    tempForComp = 25;
  }

  let tempCompFactor = 1 + tdsTempCoeff * (tempForComp - 25);
  if (tempCompFactor < 0.1) {
    tempCompFactor = 0.1;
  }

  const compensatedVoltage = voltage / tempCompFactor;
  let ppm =
    (133.42 * compensatedVoltage * compensatedVoltage * compensatedVoltage -
      255.86 * compensatedVoltage * compensatedVoltage +
      857.39 * compensatedVoltage) *
    0.5;
  ppm *= tdsScaleFactor;

  return Math.min(2000, Math.max(0, ppm));
}

function calculatepH(voltage, ph7Voltage = 2.075, phSlope = -0.059) {
  // Arduino formula: pH = 7 + ((2.5 - voltage) / 0.18)
  // Note: ph7Voltage and phSlope parameters kept for backwards compatibility but not used

  if (voltage < 0 || voltage > 3.3) {
    return 7;
  }

  const ph = 7 + (2.5 - voltage) / 0.18;
  return Math.min(14, Math.max(0, ph));
}

function normalizeEsp32Payload(payload) {
  const rawTurbidity = toFiniteNumber(payload?.rawTurbidity);
  const rawTds = toFiniteNumber(payload?.rawTds);
  const rawPh = toFiniteNumber(payload?.rawPh);
  const temperature = toFiniteNumber(payload?.temperature);

  const ph7Voltage = toFiniteNumber(payload?.ph7Voltage) ?? 2.075;
  const phSlope = toFiniteNumber(payload?.phSlope) ?? -0.059;
  const turbClearVoltage = toFiniteNumber(payload?.turbClearVoltage) ?? 1.6;
  const turbDirtyVoltage = toFiniteNumber(payload?.turbDirtyVoltage) ?? 0.6;
  const tdsScaleFactor = toFiniteNumber(payload?.tdsScaleFactor) ?? 1;
  const tdsTempCoeff = toFiniteNumber(payload?.tdsTempCoeff) ?? 0.02;

  const fallbackTurbidity = toFiniteNumber(payload?.turbidity);
  const fallbackTds = toFiniteNumber(payload?.tds);
  const fallbackPh = toFiniteNumber(payload?.phLevel);

  const rawTurbidityVoltage =
    rawTurbidity === null ? null : adcToVoltage(rawTurbidity);
  const rawTdsVoltage = rawTds === null ? null : adcToVoltage(rawTds);
  const rawPhVoltage = rawPh === null ? null : adcToVoltage(rawPh);

  const turbidity =
    rawTurbidityVoltage === null
      ? fallbackTurbidity
      : calculateNTU(rawTurbidityVoltage, turbClearVoltage, turbDirtyVoltage);
  const tds =
    rawTdsVoltage === null
      ? fallbackTds
      : calculateTDS(
          rawTdsVoltage,
          temperature ?? 25,
          tdsScaleFactor,
          tdsTempCoeff,
        );
  const phLevel =
    rawPhVoltage === null
      ? fallbackPh
      : calculatepH(rawPhVoltage, ph7Voltage, phSlope);

  if (
    turbidity === null ||
    tds === null ||
    phLevel === null ||
    temperature === null
  ) {
    throw new Error(
      "rawTurbidity, rawTds, rawPh, and temperature are required numbers",
    );
  }

  return {
    rawTurbidity,
    rawTds,
    rawPh,
    rawTurbidityVoltage,
    rawTdsVoltage,
    rawPhVoltage,
    temperature,
    ph7Voltage,
    phSlope,
    turbClearVoltage,
    turbDirtyVoltage,
    tdsScaleFactor,
    tdsTempCoeff,
    turbidity,
    tds,
    phLevel,
  };
}

async function readEsp32LiveData() {
  const firestore = getFirestore();
  const liveRef = firestore
    .collection(STATE_COLLECTION)
    .doc(ESP32_LIVE_DOCUMENT);
  const snapshot = await liveRef.get();

  if (!snapshot.exists) {
    return null;
  }

  const raw = snapshot.data() || {};

  const turbidity = toFiniteNumber(raw.turbidity);
  const tds = toFiniteNumber(raw.tds);
  const phLevel = toFiniteNumber(raw.phLevel);
  const temperature = toFiniteNumber(raw.temperature);
  const updatedAt =
    typeof raw.updatedAt === "string"
      ? raw.updatedAt
      : new Date().toISOString();

  if (
    turbidity === null &&
    tds === null &&
    phLevel === null &&
    temperature === null
  ) {
    return null;
  }

  return {
    turbidity,
    tds,
    phLevel,
    temperature,
    updatedAt,
  };
}

async function getSensorReadings({
  sensorId = null,
  from = null,
  to = null,
  limit = 10000,
} = {}) {
  const firestore = getFirestore();
  let q = firestore.collection(READINGS_COLLECTION);

  // Apply filters in order: equality first, then inequalities
  if (sensorId) {
    q = q.where("sensorId", "==", sensorId);
  }

  // For timestamp range, use a combined approach to avoid composite index issues
  if (from || to) {
    // Firestore compound index optimization:
    // Only use range queries without multiple inequality filters on different fields
    if (from && to) {
      // Both bounds: need to order by timestamp
      q = q.where("timestamp", ">=", from).where("timestamp", "<=", to);
    } else if (from) {
      q = q.where("timestamp", ">=", from);
    } else if (to) {
      q = q.where("timestamp", "<=", to);
    }
  }

  q = q.orderBy("timestamp", "asc").limit(limit);

  try {
    const snapshot = await q.get();
    if (snapshot.empty) return [];
    return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (error) {
    console.error("Error in getSensorReadings:", error);
    throw error;
  }
}

async function upsertSensorValue(sensorId, nextValue, updatedAt) {
  const firestore = getFirestore();
  const sensorRef = firestore.collection(SENSORS_COLLECTION).doc(sensorId);

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sensorRef);
    const existing = snapshot.exists ? snapshot.data() : { id: sensorId };
    const previousValue =
      typeof existing.value === "number" && Number.isFinite(existing.value)
        ? existing.value
        : nextValue;

    let trend = "stable";
    if (nextValue > previousValue) {
      trend = "up";
    } else if (nextValue < previousValue) {
      trend = "down";
    }

    transaction.set(
      sensorRef,
      {
        ...existing,
        id: sensorId,
        previousValue,
        value: nextValue,
        trend,
        updatedAt,
      },
      { merge: true },
    );
  });
}

async function ingestEsp32LiveData(payload) {
  const normalized = normalizeEsp32Payload(payload);

  const firestore = getFirestore();
  const updatedAt = new Date().toISOString();

  await firestore
    .collection(STATE_COLLECTION)
    .doc(ESP32_LIVE_DOCUMENT)
    .set(
      {
        ...normalized,
        source: "esp32",
        updatedAt,
      },
      { merge: true },
    );

  await Promise.all([
    upsertSensorValue("turbidity", normalized.turbidity, updatedAt),
    upsertSensorValue("tds", normalized.tds, updatedAt),
    upsertSensorValue("ph-level", normalized.phLevel, updatedAt),
    upsertSensorValue("temperature", normalized.temperature, updatedAt),
  ]);

  // Persist time-series readings for historical queries / exports
  try {
    const batch = firestore.batch();
    const readingsRef = firestore.collection(READINGS_COLLECTION);

    const makeReadingDoc = (sensorId, value, unit) => {
      const docRef = readingsRef.doc();
      batch.set(docRef, {
        sensorId,
        value,
        unit: unit || null,
        timestamp: updatedAt,
        source: "esp32",
      });
    };

    makeReadingDoc("turbidity", normalized.turbidity, "NTU");
    makeReadingDoc("tds", normalized.tds, "mg/L");
    makeReadingDoc("ph-level", normalized.phLevel, "pH");
    makeReadingDoc("temperature", normalized.temperature, "°C");

    await batch.commit();
  } catch (err) {
    console.error("Failed to write sensor readings history:", err);
  }

  return {
    ...normalized,
    updatedAt,
  };
}

module.exports = {
  readDb,
  updateDb,
  readEsp32LiveData,
  ingestEsp32LiveData,
  readSensors,
  updateSensor,
  getSensorReadings,
  getUserByEmail,
  getUserById,
  addUser,
  setPasswordResetToken,
  updateUserPassword,
};
