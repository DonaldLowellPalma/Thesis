const express = require("express");
const {
  readSensors,
  readEsp32LiveData,
  updateSensor,
  ingestEsp32LiveData,
  getSensorReadings,
} = require("../db");
const { getFirestore } = require("../firebase");
const {
  sendMulticastNotification,
} = require("../services/notification_service");
const { requireAuth } = require("../middleware/auth");
const {
  getSensorStatus,
  getDashboardSummary,
  calculateNSFWQI,
  getWQICategory,
} = require("../utils");

const router = express.Router();

const sseClients = new Set();

function writeSseEvent(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

async function buildRealtimeSensorsPayload() {
  const sensors = await readSensors();
  const liveData = await readEsp32LiveData();
  const sensorsWithStatus = applyEsp32LiveValues(sensors, liveData).map(
    (sensor) => ({
      ...sensor,
      status: getSensorStatus(sensor),
    }),
  );

  const turbidity =
    sensorsWithStatus.find((s) => s.id === "turbidity")?.value || 0;
  const phLevel =
    sensorsWithStatus.find((s) => s.id === "ph-level")?.value || 7.0;
  const temperature =
    sensorsWithStatus.find((s) => s.id === "temperature")?.value || 25;
  const tds = sensorsWithStatus.find((s) => s.id === "tds")?.value || 500;

  const wqiScore = calculateNSFWQI(turbidity, phLevel, temperature, tds);
  const wqiCategory = getWQICategory(wqiScore);
  const timestamp = liveData?.updatedAt || new Date().toISOString();

  let predictionCategory = "SAFE_FOR_WASHING";
  let predictionClassification = "warning";
  let predictionExplanation = "Suitable for washing and non-drinking uses.";
  let predictionRecommendation =
    "Use for cleaning/bathing. Apply filtration and disinfection before drinking.";

  if (wqiScore >= 85) {
    predictionCategory = "EXCELLENT";
    predictionClassification = "safe";
    predictionExplanation =
      "Water quality is excellent across current sensor readings.";
    predictionRecommendation =
      "Safe for most household uses. Continue regular monitoring and periodic lab testing.";
  } else if (wqiScore >= 70) {
    predictionCategory = "DRINKABLE_WITH_TREATMENT";
    predictionClassification = "safe";
    predictionExplanation =
      "Good quality detected, but treatment is still recommended before drinking.";
    predictionRecommendation =
      "Filter and disinfect (boil/UV/chlorine) before drinking.";
  } else if (
    wqiScore < 45 ||
    turbidity > 50 ||
    tds > 1500 ||
    phLevel < 5.5 ||
    phLevel > 9.5
  ) {
    predictionCategory = "NOT_RECOMMENDED";
    predictionClassification = "unsafe";
    predictionExplanation =
      "At least one parameter is in a high-risk range for household use.";
    predictionRecommendation =
      "Avoid drinking and sensitive uses. Use an alternative source or perform advanced treatment.";
  }

  return {
    sensors: sensorsWithStatus,
    wqi: {
      wqiScore,
      category: wqiCategory.status,
      color: wqiCategory.color,
      timestamp,
      sensors: {
        turbidity,
        phLevel,
        temperature,
        tds,
      },
    },
    prediction: {
      category: predictionCategory,
      classification: predictionClassification,
      score: Math.round(wqiScore),
      risk: Math.round(wqiScore),
      explanation: predictionExplanation,
      recommendation: predictionRecommendation,
      timestamp,
    },
    timestamp,
  };
}

function broadcastSensorsPayload(payload) {
  for (const client of Array.from(sseClients)) {
    try {
      writeSseEvent(client.res, "sensors", payload);
    } catch (error) {
      clearInterval(client.keepAliveTimer);
      sseClients.delete(client);
    }
  }
}

router.get("/stream", requireAuth, async (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders?.();

  const keepAliveTimer = setInterval(() => {
    try {
      res.write(`: keepalive ${Date.now()}\n\n`);
    } catch {
      clearInterval(keepAliveTimer);
    }
  }, 25000);

  const client = { res, keepAliveTimer };
  sseClients.add(client);

  try {
    const payload = await buildRealtimeSensorsPayload();
    writeSseEvent(res, "sensors", payload);
  } catch (error) {
    writeSseEvent(res, "error", { message: "Failed to load initial sensors" });
  }

  req.on("close", () => {
    clearInterval(keepAliveTimer);
    sseClients.delete(client);
    res.end();
  });
});

function applyEsp32LiveValues(sensors, liveData) {
  if (!liveData) {
    return sensors;
  }

  return sensors.map((sensor) => {
    let incomingValue = null;

    if (sensor.id === "turbidity") {
      incomingValue = liveData.turbidity;
    } else if (sensor.id === "tds") {
      incomingValue = liveData.tds;
    } else if (sensor.id === "ph-level") {
      incomingValue = liveData.phLevel;
    } else if (sensor.id === "temperature") {
      incomingValue = liveData.temperature;
    }

    if (incomingValue === null) {
      return sensor;
    }

    let trend = "stable";
    if (incomingValue > sensor.value) {
      trend = "up";
    } else if (incomingValue < sensor.value) {
      trend = "down";
    }

    return {
      ...sensor,
      previousValue: sensor.value,
      value: incomingValue,
      trend,
      updatedAt: liveData.updatedAt,
    };
  });
}

router.post("/ingest", async (req, res) => {
  const expectedKey = process.env.ESP32_INGEST_KEY;
  const providedKey = req.get("x-ingest-key") || "";

  if (expectedKey && providedKey !== expectedKey) {
    return res.status(401).json({ message: "Invalid ingest key" });
  }

  try {
    const stored = await ingestEsp32LiveData(req.body);
    const realtimePayload = await buildRealtimeSensorsPayload();
    broadcastSensorsPayload(realtimePayload);

    // Check for deviations from neutral/baseline readings and notify
    try {
      const sensors = await readSensors();
      const alerts = [];

      const ph = stored.phLevel;
      const turb = stored.turbidity;
      const tds = stored.tds;
      const temp = stored.temperature;

      // pH: neutral = 7.0 (notify if not neutral)
      if (typeof ph === "number") {
        if (ph < 7) {
          alerts.push({
            title: "pH Alert",
            body: `pH ${ph} (acidic). Acidic water can corrode pipes and release metals (lead, copper), reduce disinfection effectiveness, and irritate skin/eyes. Possible causes: industrial discharge, acid rain, or failing neutralization. Recommended: avoid drinking, test in lab, and use treated/alternative source.`,
          });
        } else if (ph > 7) {
          alerts.push({
            title: "pH Alert",
            body: `pH ${ph} (alkaline). Strongly alkaline water can cause skin/eye irritation, scale buildup, and reduce treatment effectiveness. Possible causes: industrial/base contamination or natural mineral content. Recommended: avoid drinking, test, and adjust pH or use treatment before use.`,
          });
        }
      }

      // Turbidity: baseline from sensor default, notify when change >= 1 NTU
      const turbSensor = sensors.find((s) => s.id === "turbidity");
      if (typeof turb === "number" && turbSensor) {
        const baseline = turbSensor.value ?? 0;
        if (Math.abs(turb - baseline) >= 1) {
          const dir = turb > baseline ? "above" : "below";
          alerts.push({
            title: "Turbidity Alert",
            body: `Turbidity ${dir} baseline: ${turb} NTU. High turbidity means suspended particles that can shield bacteria/viruses from disinfectants and often indicates runoff or contamination. Risks: increased infection risk and clogged filters. Recommended: avoid drinking without filtration/boiling and inspect source.`,
          });
        }
      }

      // TDS: baseline notify when change >= 50 mg/L
      const tdsSensor = sensors.find((s) => s.id === "tds");
      if (typeof tds === "number" && tdsSensor) {
        const baseline = tdsSensor.value ?? 0;
        if (Math.abs(tds - baseline) >= 50) {
          const dir = tds > baseline ? "above" : "below";
          alerts.push({
            title: "TDS Alert",
            body: `TDS ${dir} baseline: ${tds} mg/L. Elevated TDS indicates high dissolved salts/minerals which affect taste, may indicate saline or industrial contamination, and can cause scaling. Risks: health issues (high sodium), appliance damage. Recommended: test for specific contaminants and use appropriate treatment (RO) or alternative source.`,
          });
        }
      }

      // Temperature: baseline notify when change >= 2 °C
      const tempSensor = sensors.find((s) => s.id === "temperature");
      if (typeof temp === "number" && tempSensor) {
        const baseline = tempSensor.value ?? 0;
        if (Math.abs(temp - baseline) >= 2) {
          const dir = temp > baseline ? "above" : "below";
          alerts.push({
            title: "Temperature Alert",
            body: `Temperature ${dir} baseline: ${temp} °C. High temperatures speed microbial growth and lower dissolved oxygen, increasing contamination risk; very low temps can affect sensor accuracy. Risks: increased pathogen growth, algal blooms, stressed aquatic life. Recommended: avoid using warm water for drinking/storage and investigate heat sources.`,
          });
        }
      }

      if (alerts.length > 0) {
        // Collect all registered device tokens across users
        const db = getFirestore();
        const usersSnap = await db.collection("users").get();
        const tokens = [];
        for (const doc of usersSnap.docs) {
          const tokensSnap = await db
            .collection("users")
            .doc(doc.id)
            .collection("deviceTokens")
            .get();
          for (const tdoc of tokensSnap.docs) {
            const tok = tdoc.data()?.token;
            if (tok) tokens.push(tok);
          }
        }

        if (tokens.length > 0) {
          // send combined alert (simple payload) as multicast
          const title = "WaterGuard Sensor Alert";
          const body = alerts.map((a) => a.body).join("; ");
          await sendMulticastNotification(tokens, title, body, {
            type: "sensor_alert",
          });
        }
      }
    } catch (err) {
      console.error("Error evaluating/dispatching sensor alerts:", err);
    }

    return res.json({ ok: true, data: stored });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
});

router.get("/", requireAuth, async (req, res) => {
  const sensors = await readSensors();
  const liveData = await readEsp32LiveData();
  const sensorsData = applyEsp32LiveValues(sensors, liveData).map((sensor) => ({
    ...sensor,
    status: getSensorStatus(sensor),
  }));

  return res.json(sensorsData);
});

router.get("/dashboard", requireAuth, async (req, res) => {
  const sensors = await readSensors();
  const liveData = await readEsp32LiveData();
  const sensorsWithLiveData = applyEsp32LiveValues(sensors, liveData);
  const summary = getDashboardSummary(sensorsWithLiveData);

  return res.json({
    ...summary,
    sensors: sensorsWithLiveData.map((sensor) => ({
      ...sensor,
      status: getSensorStatus(sensor),
    })),
  });
});

router.get("/quality-index", requireAuth, async (req, res) => {
  try {
    const sensors = await readSensors();
    const liveData = await readEsp32LiveData();
    const sensorsWithLiveData = applyEsp32LiveValues(sensors, liveData);

    // Extract current sensor values
    const turbidity =
      sensorsWithLiveData.find((s) => s.id === "turbidity")?.value || 0;
    const phLevel =
      sensorsWithLiveData.find((s) => s.id === "ph-level")?.value || 7.0;
    const temperature =
      sensorsWithLiveData.find((s) => s.id === "temperature")?.value || 25;
    const tds = sensorsWithLiveData.find((s) => s.id === "tds")?.value || 500;

    // Calculate NSF-WQI
    const wqiScore = calculateNSFWQI(turbidity, phLevel, temperature, tds);
    const wqiCategory = getWQICategory(wqiScore);

    return res.json({
      wqiScore,
      category: wqiCategory.status,
      color: wqiCategory.color,
      timestamp: liveData?.updatedAt || new Date().toISOString(),
      sensors: {
        turbidity,
        phLevel,
        temperature,
        tds,
      },
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
});

// GET /api/sensors/readings?sensorId=tds&from=2026-01-01T00:00:00Z&to=2026-05-18T00:00:00Z&format=csv
router.get("/readings", requireAuth, async (req, res) => {
  try {
    const { sensorId, from, to, format = "json", limit } = req.query;

    // Default range: last 30 days if not provided
    const now = new Date();
    const defaultFrom = new Date(
      now.getTime() - 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const defaultTo = now.toISOString();

    const qFrom = from || defaultFrom;
    const qTo = to || defaultTo;

    const max = limit ? Math.min(parseInt(limit, 10) || 10000, 20000) : 10000;

    console.log(
      `Fetching readings: sensorId=${sensorId}, from=${qFrom}, to=${qTo}, limit=${max}`,
    );

    const readings = await getSensorReadings({
      sensorId: sensorId || null,
      from: qFrom,
      to: qTo,
      limit: max,
    });

    console.log(`Found ${readings.length} readings`);

    if (String(format).toLowerCase() === "csv") {
      res.setHeader("Content-Type", "text/csv");
      const namePart = `${sensorId || "all"}_${qFrom}_${qTo}`.replace(
        /[:]/g,
        "-",
      );
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="sensor_readings_${namePart}.csv"`,
      );

      // CSV header
      const rows = ["timestamp,sensorId,value,unit,source"];
      for (const r of readings) {
        const line = `${r.timestamp},${r.sensorId},${r.value},${r.unit || ""},${r.source || ""}`;
        rows.push(line);
      }

      return res.send(rows.join("\n"));
    }

    return res.json({ count: readings.length, readings });
  } catch (error) {
    console.error("Error in GET /readings:", error);
    return res.status(500).json({
      message: error.message,
      details: error.code || "UNKNOWN_ERROR",
    });
  }
});

router.patch("/:id/value", requireAuth, async (req, res) => {
  const { id } = req.params;
  const { value } = req.body;

  if (typeof value !== "number") {
    return res.status(400).json({ message: "value (number) is required" });
  }

  try {
    const sensors = await readSensors();
    const sensor = sensors.find((item) => item.id === id);

    if (!sensor) {
      return res.status(404).json({ message: "Sensor not found" });
    }

    let trend = "stable";
    if (value > sensor.value) {
      trend = "up";
    } else if (value < sensor.value) {
      trend = "down";
    }

    const updatedSensor = await updateSensor(id, {
      previousValue: sensor.value,
      value,
      trend,
      updatedAt: new Date().toISOString(),
    });

    return res.json({
      ...updatedSensor,
      status: getSensorStatus(updatedSensor),
    });
  } catch (error) {
    return res.status(404).json({ message: error.message });
  }
});

module.exports = router;
