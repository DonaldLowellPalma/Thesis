const express = require("express");
const router = express.Router();
const path = require("path");
const { PythonShell } = require("python-shell");

const CATEGORY_TO_CLASSIFICATION = {
  EXCELLENT: "safe",
  DRINKABLE_WITH_TREATMENT: "safe",
  SAFE_FOR_WASHING: "warning",
  NOT_RECOMMENDED: "unsafe",
};

function normalizeInput(payload) {
  return {
    turbidity: Number(payload.turbidity || payload.turb || 0),
    tds: Number(payload.tds || 0),
    ph: Number(payload.phLevel || payload.ph || 7),
    temperature: Number(payload.temperature || 0),
  };
}

function buildSignals(payload) {
  const { turbidity: turb, tds, ph, temperature } = normalizeInput(payload);
  const signals = [];

  if (turb <= 30)
    signals.push("turbidity is low, so the water looks relatively clear");
  else if (turb <= 120)
    signals.push("turbidity is moderate, which suggests some cloudiness");
  else signals.push("turbidity is high, which suggests dirty or cloudy water");

  if (tds <= 500)
    signals.push(
      "TDS is low to moderate, which usually means fewer dissolved solids",
    );
  else if (tds <= 1500)
    signals.push(
      "TDS is elevated, which can mean more dissolved salts or minerals",
    );
  else
    signals.push("TDS is very high, which often indicates poor water quality");

  if (ph >= 6.5 && ph <= 8.5)
    signals.push("pH is within the normal safe range");
  else signals.push("pH is outside the normal safe range");

  if (temperature > 0)
    signals.push(`temperature is ${temperature.toFixed(1)}°C`);

  return signals;
}

async function predictWithBestModel(payload) {
  const input = normalizeInput(payload);

  return new Promise((resolve, reject) => {
    const options = {
      mode: "text",
      pythonPath: process.env.PYTHON_PATH || "python",
      pythonOptions: ["-u"],
      scriptPath: path.join(__dirname, "../../"),
      args: [JSON.stringify(input)],
    };

    const pyshell = new PythonShell("predict_water_quality.py", options);
    const chunks = [];

    pyshell.on("message", (msg) => chunks.push(msg));
    pyshell.on("error", reject);
    pyshell.on("close", () => {
      try {
        const out = chunks.join("\n").trim();
        if (!out) return reject(new Error("No output from Python model"));
        resolve(JSON.parse(out));
      } catch (err) {
        reject(err);
      }
    });
  });
}

function buildExplanation(prediction, payload, fallback = false) {
  const classification = String(prediction.classification || "unknown");
  const score = prediction.score ?? prediction.risk;
  const signals = buildSignals(payload);
  let lead = "";

  if (classification === "safe") {
    lead = "The model considers this water safe based on the current readings.";
  } else if (classification === "warning") {
    lead =
      "The model sees early signs that water quality may be moving out of the safe range.";
  } else if (classification === "unsafe") {
    lead =
      "The model flags this water as unsafe because one or more readings are outside the safe range.";
  } else {
    lead = "The model returned a classification for the current readings.";
  }

  const parts = [lead];
  if (typeof score === "number") {
    parts.push(`Confidence or risk score: ${(score * 100).toFixed(0)}%.`);
  }
  parts.push(`Key signals: ${signals.join("; ")}.`);
  if (fallback) {
    parts.push(
      "This explanation is based on threshold rules because the trained model was not available.",
    );
  }
  return parts.join(" ");
}

// POST /api/predict
// Legacy-compatible prediction endpoint backed by the best assessment model.
router.post("/", async (req, res, next) => {
  try {
    const payload = req.body || {};
    const modelResult = await predictWithBestModel(payload);

    const category = String(modelResult.category || "NOT_RECOMMENDED");
    const classification = CATEGORY_TO_CLASSIFICATION[category] || "warning";
    const score =
      typeof modelResult.confidence === "number"
        ? modelResult.confidence
        : classification === "safe"
          ? 0.9
          : classification === "warning"
            ? 0.6
            : 0.2;

    const prediction = {
      classification,
      score,
      method: "best-model",
      category,
      explanation: buildExplanation({ classification, score }, payload, false),
      recommendation:
        category === "EXCELLENT"
          ? "No action needed."
          : category === "DRINKABLE_WITH_TREATMENT"
            ? "Treat water before drinking (filter and disinfect)."
            : category === "SAFE_FOR_WASHING"
              ? "Use for washing only; avoid drinking."
              : "Do not use for drinking or personal use.",
      signals: buildSignals(payload),
      probabilities: modelResult.probabilities,
    };

    return res.json({ ok: true, prediction });
  } catch (err) {
    const payload = req.body || {};
    const fallback = {
      classification: "warning",
      score: 0.5,
      method: "fallback",
      explanation: buildExplanation(
        { classification: "warning", score: 0.5 },
        payload,
        true,
      ),
      recommendation:
        "Model unavailable. Use caution and validate water manually.",
      signals: buildSignals(payload),
    };
    return res.json({ ok: true, prediction: fallback });
  }
});

module.exports = router;
