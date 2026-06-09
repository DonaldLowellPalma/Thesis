// Simulation script for ingest alerts (dry-run)
// Run with: node tools/simulate_ingest.js

function getDefaultSensors() {
  return [
    { id: "ph-level", name: "pH Level", value: 7.2, unit: "pH" },
    { id: "turbidity", name: "Turbidity", value: 1.5, unit: "NTU" },
    { id: "tds", name: "TDS", value: 320, unit: "mg/L" },
    { id: "temperature", name: "Temperature", value: 25.3, unit: "°C" },
  ];
}

// Simulated incoming normalized payload from ESP32
const stored = {
  phLevel: 6.3, // acidic
  turbidity: 3.0, // higher than baseline 1.5
  tds: 400, // +80 vs baseline 320
  temperature: 28.5, // +3.2 vs baseline 25.3
};

function simulateAlerts(stored, sensors) {
  const alerts = [];

  const ph = stored.phLevel;
  const turb = stored.turbidity;
  const tds = stored.tds;
  const temp = stored.temperature;

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

  const turbSensor = sensors.find((s) => s.id === "turbidity");
  if (typeof turb === "number" && turbSensor) {
    const baseline = turbSensor.value ?? 0;
    if (Math.abs(turb - baseline) >= 1) {
      alerts.push({
        title: "Turbidity Alert",
        body: `Turbidity ${turb} NTU. High turbidity means suspended particles that can shield bacteria/viruses from disinfectants and often indicates runoff or contamination. Risks: increased infection risk and clogged filters. Recommended: avoid drinking without filtration/boiling and inspect source.`,
      });
    }
  }

  const tdsSensor = sensors.find((s) => s.id === "tds");
  if (typeof tds === "number" && tdsSensor) {
    const baseline = tdsSensor.value ?? 0;
    if (Math.abs(tds - baseline) >= 50) {
      alerts.push({
        title: "TDS Alert",
        body: `TDS ${tds} mg/L. Elevated TDS indicates high dissolved salts/minerals which affect taste, may indicate saline or industrial contamination, and can cause scaling. Risks: health issues (high sodium), appliance damage. Recommended: test for specific contaminants and use appropriate treatment (RO) or alternative source.`,
      });
    }
  }

  const tempSensor = sensors.find((s) => s.id === "temperature");
  if (typeof temp === "number" && tempSensor) {
    const baseline = tempSensor.value ?? 0;
    if (Math.abs(temp - baseline) >= 2) {
      alerts.push({
        title: "Temperature Alert",
        body: `Temperature ${temp} °C. High temperatures speed microbial growth and lower dissolved oxygen, increasing contamination risk; very low temps can affect sensor accuracy. Risks: increased pathogen growth, algal blooms, stressed aquatic life. Recommended: avoid using warm water for drinking/storage and investigate heat sources.`,
      });
    }
  }

  return alerts;
}

function run() {
  const sensors = getDefaultSensors();
  console.log("Baseline sensors:", sensors);
  console.log("Incoming stored payload:", stored);

  const alerts = simulateAlerts(stored, sensors);
  if (alerts.length === 0) {
    console.log("No alerts generated (within neutral/baseline thresholds).");
    return;
  }

  console.log("Generated alerts:");
  alerts.forEach((a) => console.log(`- ${a.title}: ${a.body}`));

  const title = "WaterGuard Sensor Alert";
  const body = alerts.map((a) => a.body).join("; ");
  const payload = { title, body, data: { type: "sensor_alert" } };

  console.log("\nSimulated multicast payload to FCM tokens:");
  console.log(JSON.stringify(payload, null, 2));
  console.log(
    "\nNote: This is a dry-run simulation and does not contact Firebase.",
  );
}

run();
