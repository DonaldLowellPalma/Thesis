function getSensorStatus(sensor) {
  if (sensor.value < sensor.minSafe || sensor.value > sensor.maxSafe) {
    return "danger";
  }

  if (sensor.value < sensor.minSafe + 1 || sensor.value > sensor.maxSafe - 1) {
    return "warning";
  }

  return "safe";
}

// NSF-WQI Q-value curves (0-100 scale, higher is better)
function getQTurbidity(ntu) {
  // Turbidity in NTU: 0=100, 5=90, 10=80, 50=40, 100=20, 200=5, >500=0
  if (ntu <= 0) return 100;
  if (ntu <= 5) return 100 - (ntu / 5) * 10;
  if (ntu <= 10) return 90 - ((ntu - 5) / 5) * 10;
  if (ntu <= 50) return 80 - ((ntu - 10) / 40) * 40;
  if (ntu <= 100) return 40 - ((ntu - 50) / 50) * 20;
  if (ntu <= 200) return 20 - ((ntu - 100) / 100) * 15;
  if (ntu <= 500) return 5 - ((ntu - 200) / 300) * 5;
  return 0;
}

function getQpH(ph) {
  // pH optimal at 7-8, worse as it deviates
  if (ph >= 6.5 && ph <= 8.5) {
    // Optimal range: 100 at 7.0, slight drop towards boundaries
    const distance = Math.abs(ph - 7.0);
    return 100 - distance * 10;
  }
  if (ph >= 6.0 && ph < 6.5) {
    return 80 - ((6.5 - ph) / 0.5) * 20;
  }
  if (ph > 8.5 && ph <= 9.0) {
    return 80 - ((ph - 8.5) / 0.5) * 20;
  }
  if (ph >= 5.0 && ph < 6.0) {
    return 60 - ((6.0 - ph) / 1.0) * 30;
  }
  if (ph > 9.0 && ph <= 10.0) {
    return 50 - ((ph - 9.0) / 1.0) * 30;
  }
  // Very acidic or alkaline
  if (ph < 5.0 || ph > 10.0) return 10;
  return 100;
}

function getQTemperature(tempC) {
  // Temperature optimal around 20-25°C
  if (tempC >= 20 && tempC <= 25) {
    return 100 - Math.abs(tempC - 22.5) * 2;
  }
  if (tempC >= 15 && tempC < 20) {
    return 100 - ((20 - tempC) / 5) * 20;
  }
  if (tempC > 25 && tempC <= 30) {
    return 100 - ((tempC - 25) / 5) * 20;
  }
  if (tempC >= 10 && tempC < 15) {
    return 80 - ((15 - tempC) / 5) * 30;
  }
  if (tempC > 30 && tempC <= 35) {
    return 80 - ((tempC - 30) / 5) * 30;
  }
  if (tempC < 0 || tempC > 35) return 20;
  return 100;
}

function getQTDS(tdsPpm) {
  // TDS (Total Dissolved Solids): 0=100, 100=95, 500=70, 1000=40, 1500=20, >2000=0
  if (tdsPpm <= 0) return 100;
  if (tdsPpm <= 100) return 100 - (tdsPpm / 100) * 5;
  if (tdsPpm <= 500) return 95 - ((tdsPpm - 100) / 400) * 25;
  if (tdsPpm <= 1000) return 70 - ((tdsPpm - 500) / 500) * 30;
  if (tdsPpm <= 1500) return 40 - ((tdsPpm - 1000) / 500) * 20;
  if (tdsPpm <= 2000) return 20 - ((tdsPpm - 1500) / 500) * 20;
  return 0;
}

function calculateNSFWQI(turbidityNTU, phValue, tempC, tdsPpm) {
  // Simplified NSF-WQI using available 4 parameters
  // Weights: Turbidity (25%), pH (25%), Temperature (15%), TDS (35%)

  const qTurbidity = getQTurbidity(turbidityNTU);
  const qPh = getQpH(phValue);
  const qTemp = getQTemperature(tempC);
  const qTds = getQTDS(tdsPpm);

  const wqi = 0.25 * qTurbidity + 0.25 * qPh + 0.15 * qTemp + 0.35 * qTds;

  return Math.round(wqi * 10) / 10; // Round to 1 decimal place
}

function getWQICategory(wqiScore) {
  if (wqiScore >= 90) return { status: "Excellent", color: "#6BCB77" };
  if (wqiScore >= 70) return { status: "Good", color: "#9CCC65" };
  if (wqiScore >= 50) return { status: "Fair", color: "#FFD93D" };
  if (wqiScore >= 25) return { status: "Poor", color: "#FF9D5C" };
  return { status: "Very Poor", color: "#FF6B6B" };
}

function getDashboardSummary(sensors) {
  if (!sensors.length) {
    return { qualityScore: 0, qualityStatus: "Poor", alertCount: 0 };
  }

  const sensorScores = sensors.map((sensor) => {
    const status = getSensorStatus(sensor);
    if (status === "safe") return 100;
    if (status === "warning") return 60;
    return 20;
  });

  const qualityScore = Math.floor(
    sensorScores.reduce((sum, score) => sum + score, 0) / sensorScores.length,
  );

  const qualityStatus =
    qualityScore >= 80
      ? "Excellent"
      : qualityScore >= 60
        ? "Good"
        : qualityScore >= 40
          ? "Fair"
          : "Poor";

  const alertCount = sensors.filter(
    (sensor) => getSensorStatus(sensor) !== "safe",
  ).length;

  return { qualityScore, qualityStatus, alertCount };
}

module.exports = {
  getSensorStatus,
  getDashboardSummary,
  calculateNSFWQI,
  getWQICategory,
  getQTurbidity,
  getQpH,
  getQTemperature,
  getQTDS,
};
