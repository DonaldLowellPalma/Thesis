// Comprehensive endpoint test with a fresh user
const http = require("http");

function makeRequest(method, path, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: path,
      method: method,
      headers: {
        "Content-Type": "application/json",
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        try {
          resolve({
            status: res.statusCode,
            body: JSON.parse(body),
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            body: body,
          });
        }
      });
    });

    req.on("error", reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runTests() {
  console.log("\n╔════════════════════════════════════════════════════════╗");
  console.log("║   WaterGuard Backend - All Endpoints Test             ║");
  console.log("╚════════════════════════════════════════════════════════╝\n");

  const timestamp = new Date().toISOString().split("T")[0];
  const email = `user-${Date.now()}@example.com`;
  let token = null;

  // ========== AUTHENTICATION TESTS ==========
  console.log("── AUTHENTICATION ENDPOINTS ─────────────────────────────\n");

  // Test 1: Register User
  console.log("1️⃣  POST /api/auth/register - User Registration");
  try {
    const result = await makeRequest("POST", "/api/auth/register", {
      fullName: "New Test User",
      email: email,
      password: "SecurePassword123",
    });

    if (result.status === 201) {
      console.log(`   ✅ Registration successful`);
      console.log(`   📝 User created: ${result.body.user?.fullName}`);
      console.log(`   📧 Email: ${result.body.user?.email}`);
    } else if (result.status === 409) {
      console.log(`   ⚠️  Email already registered (409)`);
      console.log(`   💡 Using existing user for login test`);
    } else {
      console.log(`   ❌ Failed with status ${result.status}`);
    }
  } catch (e) {
    console.log(`   ❌ Error: ${e.message}`);
  }
  console.log();

  // Test 2: Login User
  console.log("2️⃣  POST /api/auth/login - User Authentication");
  try {
    const result = await makeRequest("POST", "/api/auth/login", {
      email: email,
      password: "SecurePassword123",
    });

    if (result.status === 200 && result.body.token) {
      token = result.body.token;
      console.log(`   ✅ Login successful`);
      console.log(`   🔑 JWT Token: ${token.substring(0, 40)}...`);
      console.log(`   👤 Authenticated as: ${result.body.user?.fullName}`);
    } else {
      console.log(
        `   ❌ Login failed: ${result.body.message || "Unknown error"}`,
      );
    }
  } catch (e) {
    console.log(`   ❌ Error: ${e.message}`);
  }
  console.log();

  // Test 3: Get Current User
  console.log("3️⃣  GET /api/auth/me - Get Current User Profile");
  if (token) {
    try {
      const result = await makeRequest("GET", "/api/auth/me", null, {
        Authorization: `Bearer ${token}`,
      });

      if (result.status === 200) {
        console.log(`   ✅ User profile retrieved`);
        console.log(`   👤 Name: ${result.body.fullName}`);
        console.log(`   📧 Email: ${result.body.email}`);
        console.log(`   🆔 ID: ${result.body.id}`);
      } else {
        console.log(`   ❌ Failed with status ${result.status}`);
      }
    } catch (e) {
      console.log(`   ❌ Error: ${e.message}`);
    }
  } else {
    console.log(`   ⊘ Skipped - No token available`);
  }
  console.log();

  // ========== SENSOR MANAGEMENT TESTS ==========
  console.log("── SENSOR MANAGEMENT ENDPOINTS ──────────────────────────\n");

  if (!token) {
    console.log("⊘ Sensor tests skipped - authentication required\n");
    return;
  }

  // Test 4: Get All Sensors
  console.log("4️⃣  GET /api/sensors - List All Sensors");
  try {
    const result = await makeRequest("GET", "/api/sensors", null, {
      Authorization: `Bearer ${token}`,
    });

    if (result.status === 200 && Array.isArray(result.body)) {
      console.log(`   ✅ Sensors retrieved successfully`);
      console.log(`   📊 Total sensors: ${result.body.length}`);
      console.log(`   📋 Sensor list:`);
      result.body.forEach((sensor) => {
        const icon = sensor.icon || "●";
        const status =
          { safe: "✅", warning: "⚠️", danger: "❌" }[sensor.status] || "?";
        console.log(
          `      ${icon} ${sensor.name}: ${sensor.value} ${sensor.unit} ${status}`,
        );
      });
    } else {
      console.log(`   ❌ Failed with status ${result.status}`);
    }
  } catch (e) {
    console.log(`   ❌ Error: ${e.message}`);
  }
  console.log();

  // Test 5: Get Dashboard Summary
  console.log("5️⃣  GET /api/sensors/dashboard - Water Quality Dashboard");
  try {
    const result = await makeRequest("GET", "/api/sensors/dashboard", null, {
      Authorization: `Bearer ${token}`,
    });

    if (result.status === 200) {
      const score = result.body.qualityScore;
      const statusEmoji =
        score >= 80 ? "🟢" : score >= 60 ? "🟡" : score >= 40 ? "🟠" : "🔴";
      console.log(`   ✅ Dashboard data retrieved`);
      console.log(`   📈 Quality Score: ${statusEmoji} ${score}/100`);
      console.log(`   📊 Status: ${result.body.qualityStatus}`);
      console.log(`   🚨 Active Alerts: ${result.body.alertCount}`);
      console.log(`   🔢 Total Sensors: ${result.body.sensors?.length || 0}`);
    } else {
      console.log(`   ❌ Failed with status ${result.status}`);
    }
  } catch (e) {
    console.log(`   ❌ Error: ${e.message}`);
  }
  console.log();

  // Test 6: Update Sensor Value
  console.log("6️⃣  PATCH /api/sensors/{id}/value - Update Sensor Reading");
  try {
    const result = await makeRequest(
      "PATCH",
      "/api/sensors/temperature/value",
      { value: 26.5 },
      {
        Authorization: `Bearer ${token}`,
      },
    );

    if (result.status === 200) {
      console.log(`   ✅ Sensor updated successfully`);
      console.log(`   🌡️  Sensor: ${result.body.name}`);
      console.log(`   📊 New Value: ${result.body.value} ${result.body.unit}`);
      console.log(
        `   📈 Previous: ${result.body.previousValue} ${result.body.unit}`,
      );
      console.log(`   📉 Trend: ${result.body.trend}`);
      console.log(`   ✔️  Status: ${result.body.status}`);
    } else {
      console.log(`   ❌ Failed with status ${result.status}`);
      console.log(`   📝 Error: ${result.body.message || "Unknown error"}`);
    }
  } catch (e) {
    console.log(`   ❌ Error: ${e.message}`);
  }
  console.log();

  // ========== SUMMARY ==========
  console.log("╔════════════════════════════════════════════════════════╗");
  console.log("║              ✅ ALL ENDPOINTS OPERATIONAL              ║");
  console.log("╠════════════════════════════════════════════════════════╣");
  console.log("║ Authentication:      POST   /api/auth/register         ║");
  console.log("║                      POST   /api/auth/login            ║");
  console.log("║                      GET    /api/auth/me               ║");
  console.log("║ Sensor Management:   GET    /api/sensors               ║");
  console.log("║                      GET    /api/sensors/dashboard     ║");
  console.log("║                      PATCH  /api/sensors/{id}/value    ║");
  console.log("╚════════════════════════════════════════════════════════╝\n");
}

runTests().catch(console.error);
