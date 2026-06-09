#!/usr/bin/env node
/**
 * Test script for device token endpoint
 * Tests POST /api/device/token
 *
 * Usage:
 *   node test-device-token.js [baseUrl] [deviceId] [deviceSecret]
 *
 * Examples:
 *   node test-device-token.js http://localhost:4000
 *   node test-device-token.js http://localhost:4000 device-001 waterguard-device-secret-123
 */

const http = require("http");
const https = require("https");

const baseUrl = process.argv[2] || "http://localhost:4000";
const deviceId = process.argv[3] || "device-001";
const deviceSecret = process.argv[4] || "waterguard-device-secret-123";

function parseUrl(urlString) {
  const url = new URL(urlString);
  return {
    protocol: url.protocol === "https:" ? https : http,
    hostname: url.hostname,
    port: url.port || (url.protocol === "https:" ? 443 : 80),
    path: url.pathname + url.search,
  };
}

function makeRequest(method, urlString, body) {
  return new Promise((resolve, reject) => {
    const urlObj = parseUrl(urlString);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.path,
      method: method,
      headers: {
        "Content-Type": "application/json",
      },
    };

    if (body) {
      const bodyStr = JSON.stringify(body);
      options.headers["Content-Length"] = Buffer.byteLength(bodyStr);
    }

    const req = urlObj.protocol.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data,
        });
      });
    });

    req.on("error", reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function testDeviceToken() {
  console.log("🧪 Testing Device Token Endpoint\n");
  console.log(`Base URL: ${baseUrl}`);
  console.log(`Device ID: ${deviceId}`);
  console.log(`Device Secret: ${deviceSecret}`);
  console.log();

  const tokenEndpoint = new URL("/api/device/token", baseUrl).toString();

  try {
    // Test 1: Valid credentials
    console.log("Test 1: Valid credentials");
    console.log(`POST ${tokenEndpoint}`);
    const response1 = await makeRequest("POST", tokenEndpoint, {
      deviceId,
      deviceSecret,
    });
    console.log(`Status: ${response1.status}`);
    const body1 = JSON.parse(response1.body);
    console.log(`Response: ${JSON.stringify(body1, null, 2)}`);

    if (response1.status === 200 && body1.ok && body1.token) {
      console.log("✅ Token obtained successfully");
      console.log(`Token length: ${body1.token.length} characters`);
      console.log(`Expires in: ${body1.expiresIn} seconds\n`);
    } else {
      console.log("❌ Unexpected response\n");
    }

    // Test 2: Missing deviceId
    console.log("Test 2: Missing deviceId (should fail)");
    const response2 = await makeRequest("POST", tokenEndpoint, {
      deviceSecret,
    });
    console.log(`Status: ${response2.status}`);
    const body2 = JSON.parse(response2.body);
    console.log(`Response: ${JSON.stringify(body2, null, 2)}`);
    if (response2.status === 400) {
      console.log("✅ Correctly rejected missing deviceId\n");
    } else {
      console.log("❌ Should have returned 400\n");
    }

    // Test 3: Invalid credentials
    console.log("Test 3: Invalid credentials (should fail)");
    const response3 = await makeRequest("POST", tokenEndpoint, {
      deviceId: "device-001",
      deviceSecret: "wrong-secret",
    });
    console.log(`Status: ${response3.status}`);
    const body3 = JSON.parse(response3.body);
    console.log(`Response: ${JSON.stringify(body3, null, 2)}`);
    if (response3.status === 401) {
      console.log("✅ Correctly rejected invalid credentials\n");
    } else {
      console.log("❌ Should have returned 401\n");
    }

    console.log("✅ All tests completed!");
  } catch (error) {
    console.error("❌ Error:", error.message);
    console.error("\nMake sure:");
    console.error("  1. Backend is running: npm start");
    console.error("  2. Firebase credentials are configured in .env");
    console.error("  3. DEVICE_SECRET is set in .env");
    process.exit(1);
  }
}

testDeviceToken();
