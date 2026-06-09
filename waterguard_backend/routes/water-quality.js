/**
 * Water Quality Assessment Route
 * Uses ML model to predict water quality based on sensor data
 * Integrates with trained Python water quality model
 */

const express = require("express");
const router = express.Router();
const { PythonShell } = require("python-shell");
const path = require("path");

// ============ Water Quality Categories ============

const QUALITY_CATEGORIES = {
  EXCELLENT: {
    score: 90,
    description: "Safe for direct drinking - excellent quality",
    icon: "✓✓✓",
    color: "green",
    usage: "All uses - drinking, cooking, bathing",
  },
  DRINKABLE_WITH_TREATMENT: {
    score: 70,
    description: "Safe to drink AFTER proper filtration + disinfection",
    icon: "✓✓",
    color: "yellow",
    usage: "Drinking (after treatment), cooking, bathing",
  },
  SAFE_FOR_WASHING: {
    score: 50,
    description: "Safe for washing clothes / dishes / bathing",
    icon: "✓",
    color: "orange",
    usage: "Bathing, washing, irrigation only",
  },
  NOT_RECOMMENDED: {
    score: 0,
    description: "Too dirty / Not recommended for any use",
    icon: "✗",
    color: "red",
    usage: "No household use recommended",
  },
};

// ============ Helper Functions ============

/**
 * Call Python ML model for prediction
 * Requires python-shell package: npm install python-shell
 */
async function predictWithModel(turbidity, tds, ph, temperature) {
  const timeoutMs = 5000;
  return new Promise((resolve, reject) => {
    const options = {
      mode: "text",
      pythonPath: process.env.PYTHON_PATH || "python",
      pythonOptions: ["-u"],
      scriptPath: path.join(__dirname, "../"),
      args: [
        JSON.stringify({
          turbidity: parseFloat(turbidity),
          tds: parseFloat(tds),
          ph: parseFloat(ph),
          temperature: parseFloat(temperature),
        }),
      ],
    };

    let finished = false;
    const pyshell = new PythonShell("predict_water_quality.py", options);
    const chunks = [];

    const timer = setTimeout(() => {
      if (finished) return;
      finished = true;
      try {
        if (pyshell && pyshell.childProcess) pyshell.childProcess.kill();
      } catch (e) {}
      reject(new Error("Python model timeout"));
    }, timeoutMs);

    pyshell.on("message", (msg) => {
      chunks.push(msg);
    });

    pyshell.on("error", (err) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      reject(err);
    });

    pyshell.on("close", () => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      try {
        const out = chunks.join("\n").trim();
        if (!out) return reject(new Error("No output from Python model"));
        const prediction = JSON.parse(out);
        resolve(prediction);
      } catch (e) {
        reject(e);
      }
    });
  });
}

/**
 * Rule-based fallback assessment (if Python model unavailable)
 * Simple heuristic approach
 */
function assessWaterQualityRules(turbidity, tds, ph, temperature) {
  turbidity = parseFloat(turbidity) || 0;
  tds = parseFloat(tds) || 0;
  ph = parseFloat(ph) || 7;
  temperature = parseFloat(temperature) || 25;

  // Check critical conditions (NOT_RECOMMENDED)
  if (turbidity > 25 || tds > 1500 || ph < 4.5 || ph > 10.5) {
    return {
      category: "NOT_RECOMMENDED",
      score: 0,
      confidence: 0.85,
      reason: "One or more parameters exceed safe thresholds",
    };
  }

  // Check for excellent water
  if (
    turbidity < 1 &&
    tds < 500 &&
    ph >= 6.5 &&
    ph <= 8.5 &&
    temperature >= 15 &&
    temperature <= 25
  ) {
    return {
      category: "EXCELLENT",
      score: 90,
      confidence: 0.9,
      reason: "All parameters in optimal ranges",
    };
  }

  // Check for drinkable with treatment
  if (turbidity < 3 && tds < 800 && ph >= 6.0 && ph <= 8.5) {
    return {
      category: "DRINKABLE_WITH_TREATMENT",
      score: 70,
      confidence: 0.8,
      reason: "Good quality but filtration/disinfection recommended",
    };
  }

  // Default: safe for washing
  return {
    category: "SAFE_FOR_WASHING",
    score: 50,
    confidence: 0.75,
    reason: "Acceptable for non-drinking uses",
  };
}

/**
 * Generate detailed recommendations based on water quality
 */
function generateRecommendations(category, turbidity, tds, ph, temperature) {
  const recommendations = [];
  const issues = [];

  // Identify issues
  if (turbidity > 5) issues.push("High turbidity (cloudiness)");
  if (tds > 1000) issues.push("High dissolved solids (salinity)");
  if (ph < 6.0) issues.push("High acidity");
  if (ph > 8.5) issues.push("High alkalinity");
  if (temperature < 5) issues.push("Very cold water");
  if (temperature > 35) issues.push("Very hot water");

  // Category-specific recommendations
  if (category === "EXCELLENT") {
    recommendations.push("✓ Safe for direct drinking without treatment");
    recommendations.push("✓ Ideal for all household uses");
    recommendations.push("✓ Excellent water quality - no action needed");
  } else if (category === "DRINKABLE_WITH_TREATMENT") {
    recommendations.push("⚠ Safe to drink ONLY after treatment:");
    recommendations.push("  → Option 1: Boil for 1+ minute");
    recommendations.push(
      "  → Option 2: Use certified water filter (0.5-1 micron)",
    );
    recommendations.push("  → Option 3: UV disinfection");
    recommendations.push("✓ Safe for cooking and bathing");
  } else if (category === "SAFE_FOR_WASHING") {
    recommendations.push("✓ Safe for bathing and personal hygiene");
    recommendations.push("✓ Safe for washing clothes and dishes");
    recommendations.push("✓ Safe for irrigation and gardening");
    recommendations.push("✗ DO NOT drink without proper treatment");

    if (issues.length > 0) {
      recommendations.push(`⚠ Issues: ${issues.join(", ")}`);
    }
  } else {
    // NOT_RECOMMENDED
    recommendations.push("✗ NOT safe for drinking");
    recommendations.push("✗ NOT recommended for bathing");
    recommendations.push("⚠ Use only for minimal outdoor irrigation");
    recommendations.push("⚠ May cause staining or damage to fabrics/pipes");

    if (issues.length > 0) {
      recommendations.push(`Critical issues: ${issues.join(", ")}`);
    }
  }

  return {
    recommendations,
    issues,
  };
}

// ============ Routes ============

/**
 * POST /api/water-quality/assess
 * Assess water quality based on sensor readings
 *
 * Body: {
 *   turbidity: number (NTU, 0-3000),
 *   tds: number (ppm, 0-2000),
 *   ph: number (0-14),
 *   temperature: number (Celsius)
 * }
 */
router.post("/assess", async (req, res) => {
  try {
    const { turbidity, tds, ph, temperature } = req.body;

    // Validate inputs
    if (
      turbidity === undefined ||
      tds === undefined ||
      ph === undefined ||
      temperature === undefined
    ) {
      return res.status(400).json({
        error: "Missing required fields: turbidity, tds, ph, temperature",
      });
    }

    // Validate ranges
    const turb = parseFloat(turbidity);
    const tdsVal = parseFloat(tds);
    const phVal = parseFloat(ph);
    const tempVal = parseFloat(temperature);

    if (isNaN(turb) || isNaN(tdsVal) || isNaN(phVal) || isNaN(tempVal)) {
      return res.status(400).json({
        error: "Invalid input values - must be numbers",
      });
    }

    if (
      turb < 0 ||
      turb > 3000 ||
      tdsVal < 0 ||
      tdsVal > 2000 ||
      phVal < 0 ||
      phVal > 14 ||
      tempVal < -10 ||
      tempVal > 50
    ) {
      return res.status(400).json({
        error: "Input values out of valid range",
        ranges: {
          turbidity: "0-3000 NTU",
          tds: "0-2000 ppm",
          ph: "0-14",
          temperature: "-10 to 50°C",
        },
      });
    }

    // Try to use ML model, fall back to rules
    let prediction;
    try {
      prediction = await predictWithModel(turb, tdsVal, phVal, tempVal);
    } catch (modelErr) {
      console.warn(
        "ML model unavailable, using rule-based assessment:",
        modelErr.message,
      );
      prediction = assessWaterQualityRules(turb, tdsVal, phVal, tempVal);
    }

    // Merge with quality metadata
    const assessment = {
      category: prediction.category,
      ...QUALITY_CATEGORIES[prediction.category],
      confidence: prediction.confidence || 0.85,
      timestamp: new Date().toISOString(),
      sensor_data: {
        turbidity_ntu: parseFloat(turb.toFixed(2)),
        tds_ppm: parseFloat(tdsVal.toFixed(2)),
        ph: parseFloat(phVal.toFixed(2)),
        temperature_celsius: parseFloat(tempVal.toFixed(2)),
      },
    };

    // Add recommendations
    const { recommendations, issues } = generateRecommendations(
      prediction.category,
      turb,
      tdsVal,
      phVal,
      tempVal,
    );
    assessment.recommendations = recommendations;
    assessment.issues = issues;

    // Add probability distribution if available
    if (prediction.probabilities) {
      assessment.probabilities = prediction.probabilities;
    }

    return res.json(assessment);
  } catch (error) {
    console.error("Water quality assessment error:", error);
    return res.status(500).json({
      error: "Water quality assessment failed",
      message: error.message,
    });
  }
});

/**
 * POST /api/water-quality/batch
 * Assess multiple water samples
 *
 * Body: {
 *   samples: [
 *     { turbidity, tds, ph, temperature },
 *     ...
 *   ]
 * }
 */
router.post("/batch", async (req, res) => {
  try {
    const { samples } = req.body;

    if (!Array.isArray(samples)) {
      return res.status(400).json({ error: "samples must be an array" });
    }

    const results = [];

    for (const sample of samples) {
      try {
        const { turbidity, tds, ph, temperature } = sample;

        if (
          turbidity === undefined ||
          tds === undefined ||
          ph === undefined ||
          temperature === undefined
        ) {
          results.push({
            error: "Missing required fields",
            sample,
          });
          continue;
        }

        // Try ML model, fall back to rules
        let prediction;
        try {
          prediction = await predictWithModel(turbidity, tds, ph, temperature);
        } catch {
          prediction = assessWaterQualityRules(turbidity, tds, ph, temperature);
        }

        const assessment = {
          category: prediction.category,
          ...QUALITY_CATEGORIES[prediction.category],
          confidence: prediction.confidence || 0.85,
          sensor_data: {
            turbidity_ntu: parseFloat(turbidity),
            tds_ppm: parseFloat(tds),
            ph: parseFloat(ph),
            temperature_celsius: parseFloat(temperature),
          },
        };

        const { recommendations } = generateRecommendations(
          prediction.category,
          turbidity,
          tds,
          ph,
          temperature,
        );
        assessment.recommendations = recommendations;

        results.push(assessment);
      } catch (sampleErr) {
        results.push({
          error: sampleErr.message,
          sample,
        });
      }
    }

    return res.json({
      total: samples.length,
      successful: results.filter((r) => !r.error).length,
      failed: results.filter((r) => r.error).length,
      results,
    });
  } catch (error) {
    console.error("Batch assessment error:", error);
    return res.status(500).json({
      error: "Batch assessment failed",
      message: error.message,
    });
  }
});

/**
 * GET /api/water-quality/categories
 * Get all quality categories and descriptions
 */
router.get("/categories", (req, res) => {
  return res.json(QUALITY_CATEGORIES);
});

/**
 * GET /api/water-quality/standards
 * Get water quality standards and thresholds
 */
router.get("/standards", (req, res) => {
  const standards = {
    turbidity_ntu: {
      drinking_max: 1,
      bathing_max: 5,
      irrigation_max: 25,
      description: "Lower is better - measures water clarity",
    },
    tds_ppm: {
      drinking_ideal_max: 500,
      drinking_acceptable_max: 1000,
      bathing_max: 1500,
      description: "Total Dissolved Solids - lower is fresher water",
    },
    ph: {
      optimal_min: 6.5,
      optimal_max: 8.5,
      drinking_acceptable_min: 6.0,
      drinking_acceptable_max: 8.5,
      description: "7 is neutral, <7 is acidic, >7 is alkaline",
    },
    temperature_celsius: {
      optimal_min: 15,
      optimal_max: 25,
      acceptable_min: 5,
      acceptable_max: 35,
      description: "Extreme temperatures reduce water usability",
    },
  };

  return res.json(standards);
});

module.exports = router;
