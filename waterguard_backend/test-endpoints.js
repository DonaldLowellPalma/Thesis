// Quick test for all endpoints
const http = require("http");

function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: path,
      method: method,
      headers: {
        "Content-Type": "application/json",
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
  console.log("=== WaterGuard Backend Endpoint Tests ===\n");

  let token = null;

  // Test 1: Register
  console.log("[1] POST /api/auth/register");
  try {
    const result = await makeRequest("POST", "/api/auth/register", {
      fullName: "Test User",
      email: "test@example.com",
      password: "Test123!",
    });
    console.log(`✓ Status: ${result.status}`);
    console.log(`  Message: ${result.body.message}`);
    console.log(`  User: ${result.body.user?.fullName}\n`);
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  // Test 2: Login
  console.log("[2] POST /api/auth/login");
  try {
    const result = await makeRequest("POST", "/api/auth/login", {
      email: "test@example.com",
      password: "Test123!",
    });
    console.log(`✓ Status: ${result.status}`);
    if (result.body.token) {
      token = result.body.token;
      console.log(`  Token: ${token.substring(0, 30)}...`);
      console.log(`  User: ${result.body.user?.fullName}\n`);
    } else {
      console.log(`  Error: ${result.body.message}\n`);
    }
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  if (!token) {
    console.log("Skipping remaining tests - no token\n");
    return;
  }

  // Test 3: Get current user
  console.log("[3] GET /api/auth/me");
  try {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: "/api/auth/me",
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    };

    const result = await new Promise((resolve, reject) => {
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
      req.end();
    });

    console.log(`✓ Status: ${result.status}`);
    console.log(
      `  Authenticated as: ${result.body.fullName} <${result.body.email}>\n`,
    );
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  // Test 4: Get sensors
  console.log("[4] GET /api/sensors");
  try {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: "/api/sensors",
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    };

    const result = await new Promise((resolve, reject) => {
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
      req.end();
    });

    console.log(`✓ Status: ${result.status}`);
    console.log(`  Sensors: ${result.body.length}`);
    result.body.slice(0, 3).forEach((s) => {
      console.log(`    • ${s.name}: ${s.value} ${s.unit} [${s.status}]`);
    });
    console.log();
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  // Test 5: Get dashboard
  console.log("[5] GET /api/sensors/dashboard");
  try {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: "/api/sensors/dashboard",
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    };

    const result = await new Promise((resolve, reject) => {
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
      req.end();
    });

    console.log(`✓ Status: ${result.status}`);
    console.log(`  Quality Score: ${result.body.qualityScore}/100`);
    console.log(`  Status: ${result.body.qualityStatus}`);
    console.log(`  Alerts: ${result.body.alertCount}\n`);
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  // Test 6: Update sensor
  console.log("[6] PATCH /api/sensors/{id}/value");
  try {
    const options = {
      hostname: "localhost",
      port: 4000,
      path: "/api/sensors/ph-level/value",
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
    };

    const result = await new Promise((resolve, reject) => {
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
      req.write(JSON.stringify({ value: 7.5 }));
      req.end();
    });

    console.log(`✓ Status: ${result.status}`);
    console.log(
      `  Updated: ${result.body.name} = ${result.body.value} ${result.body.unit}`,
    );
    console.log(`  Status: ${result.body.status}\n`);
  } catch (e) {
    console.log(`✗ Error: ${e.message}\n`);
  }

  console.log("=== Tests Complete ===");
}

runTests();
