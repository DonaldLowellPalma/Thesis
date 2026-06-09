const http = require("http");

const payload = JSON.stringify({
  turbidity: 2.5,
  tds: 600,
  ph: 7.2,
  temperature: 23,
});

const req = http.request(
  {
    hostname: "localhost",
    port: 4000,
    path: "/api/water-quality/assess",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(payload),
    },
    timeout: 10000,
  },
  (res) => {
    let data = "";
    res.on("data", (chunk) => {
      data += chunk;
    });
    res.on("end", () => {
      console.log("status", res.statusCode);
      console.log(data);
      process.exit(0);
    });
  },
);

req.on("timeout", () => {
  console.error("request timeout");
  req.destroy();
  process.exit(1);
});

req.on("error", (err) => {
  console.error("request error", err.message);
  process.exit(1);
});

req.write(payload);
req.end();
