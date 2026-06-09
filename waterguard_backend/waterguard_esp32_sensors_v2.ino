#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <esp_system.h>
#include <math.h>
#include <WebServer.h>

// ------------------------------------------------------------
// SAFETY DISCLAIMER (PERMANENT - PLEASE READ)
// ------------------------------------------------------------
// IMPORTANT: This device measures only physical/chemical
// indicators (pH, TDS, Turbidity, Temperature). It CANNOT
// detect bacteria, viruses, parasites, heavy metals,
// pesticides, or many organic pollutants. Even "good"
// readings do NOT guarantee microbiological safety. Always
// treat water before drinking (filter + boil/UV/chlorine)
// and periodically send samples to a DOH-accredited lab.
// High turbidity hides pathogens and reduces disinfection
// effectiveness. Use your own judgment. This disclaimer
// must remain with the firmware and any user-facing output.
// ------------------------------------------------------------

// Conservative safety thresholds (Philippines PNSDW 2017 + WHO)
static const float SAFE_PH_LOW = 6.5f;
static const float SAFE_PH_HIGH = 8.5f;

// TDS thresholds (mg/L or ppm)
static const float DRINKABLE_TDS_MAX = 600.0f; // conservative drinking threshold
static const float WASH_TDS_MAX = 2000.0f;     // tolerable for washing/laundry

// Turbidity thresholds (NTU) - based on industry standards
static const float DRINKABLE_TURBIDITY_MAX = 1.0f; // <=1 NTU (ideal for drinking; <0.3 is gold standard)
static const float WASH_TURBIDITY_MAX = 50.0f;     // up to 50 NTU visible cloudiness; still usable for washing

// Temperature thresholds (°C)
static const float MAX_TEMPERATURE_DRINK = 32.0f;
static const float MAX_TEMPERATURE_WASH = 40.0f;

// WQI weights for background logging/trends (sum = 1.0)
static const float WQI_WEIGHT_TURBIDITY = 0.40f; // highest risk for microbes
static const float WQI_WEIGHT_TDS = 0.30f;
static const float WQI_WEIGHT_PH = 0.20f;
static const float WQI_WEIGHT_TEMPERATURE = 0.10f;

// Embedded WiFi credentials - primary and fallback
#define WIFI_SSID_PRIMARY "vivo@1920@30"
#define WIFI_PASSWORD_PRIMARY "102030405060708090"
#define WIFI_SSID_FALLBACK "Borresfamily_Wifi-2G"
#define WIFI_PASSWORD_FALLBACK "02081976"

// Backend ingest endpoint (recommended secure path)
#define BACKEND_BASE_URL "https://waterguard-server.onrender.com"
#define BACKEND_INGEST_PATH "/api/sensors/ingest"
#define BACKEND_INGEST_KEY "your-long-random-secret" // Backend ingest key from .env

// Optional: send directly to Firebase Realtime Database instead of backend.
// Set `FIREBASE_DATABASE_URL` to your project's Realtime Database root (no trailing slash),
// e.g. "https://my-project.firebaseio.com". If `FIREBASE_DATABASE_URL` is empty,
// the sketch will continue to POST to the backend defined above.
// If your database requires auth, put a Database Secret or a valid token in
// `FIREBASE_DATABASE_AUTH`. Leave empty for public DB rules (not recommended).
#define FIREBASE_DATABASE_URL ""
#define FIREBASE_DATABASE_AUTH ""

// WiFi Setup Mode
#define SETUP_AP_SSID "WaterGuard-Setup"
#define SETUP_AP_PASSWORD "12345678"
#define SETUP_AP_IP IPAddress(192, 168, 4, 1)
#define SETUP_AP_GATEWAY IPAddress(192, 168, 4, 1)
#define SETUP_AP_SUBNET IPAddress(255, 255, 255, 0)

// Web server for setup mode
WebServer setupServer(80);
bool isInSetupMode = false;
bool shouldRestartAfterConfig = false;
unsigned long setupModeStartTime = 0;
static const unsigned long SETUP_MODE_TIMEOUT_MS = 600000; // 10 minutes

// Sensor pins
#define TURB_PIN 34
#define TDS_PIN 35
#define PH_PIN 32
#define TEMP_PIN 33

// Timing
static const unsigned long SENSOR_CYCLE_DELAY_MS = 3000;
static const unsigned long FIREBASE_UPDATE_INTERVAL_MS = 10000;
static const uint32_t MIN_FREE_HEAP_FOR_HTTP = 60000;
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensor(&oneWire);
Preferences calibrationPrefs;

unsigned long lastHeapLogMs = 0;
unsigned long lastFirebaseUpdateMs = 0;
unsigned long lastWiFiCheckMs = 0;
static const unsigned long WIFI_CHECK_INTERVAL_MS = 10000; // Check WiFi status every 10 seconds

static const int SENSOR_SAMPLES = 20;

static const char *CALIBRATION_NAMESPACE = "calib";
static const uint32_t CALIBRATION_MAGIC = 0x57475432; // "WGT2"

float ph7Voltage = 2.075f;
float phSlope = -0.059f;
float turbClearVoltage = 1.60f;
float turbDirtyVoltage = 0.60f;
float tdsScaleFactor = 1.0f;
float tdsTempCoeff = 0.02f;

bool connectToWiFi();
float readAverage(int pin);
float readTemperature();
float calculateNTU(float voltage);
float calculateTDS(float voltage, float temperatureC);
float calculatepH(float voltage);
void setPh7FromCurrentVoltage();
void setTurbClearFromCurrentVoltage();
void setTurbDirtyFromCurrentVoltage();
String getTurbidityCategory(float ntu);
String getTDSSalinity(float ppm);
String getpHCategory(float ph);
void loadCalibration();
void saveCalibration();
void resetCalibrationToDefaults();
void printCalibration();
void printCalibrationHelp();
void processSerialCommands();
bool applyTwoPointPhCalibration(float phA, float vA, float phB, float vB);
void assessWaterQuality(float turbidity, float tds, float ph, float temperature, float &outWQI, String &outCategory, String &outAdvice);
float score_pH(float ph);
float score_TDS(float tds);
float score_Turbidity(float turb);
float score_Temperature(float temp);
void assessWaterQuality(float turbidity, float tds, float ph, float temperature, float &outWQI, String &outCategory, String &outAdvice);

void startSetupMode();
void stopSetupMode();
void initSetupServer();
void handleScanWifi();
void handleWifiStatus();
void handleConfigureWifi();
void handleConnectWifi();
void handleStartSetupMode();
void checkSetupModeTimeout();

bool connectToWiFiNetwork(const String &ssid, const String &password, unsigned long timeoutMs)
{
    Serial.print(F("Attempting WiFi: "));
    Serial.println(ssid);

    WiFi.begin(ssid.c_str(), password.c_str());
    unsigned long startedAt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startedAt < timeoutMs)
    {
        delay(500);
        Serial.print('.');
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.print(F("WiFi connected to: "));
        Serial.print(ssid);
        Serial.print(F(", IP: "));
        Serial.println(WiFi.localIP());
        return true;
    }

    Serial.print(F("Failed to connect to: "));
    Serial.println(ssid);
    return false;
}

bool connectToWiFi()
{
    Preferences wifiPrefs;
    wifiPrefs.begin("wifi_config", true);
    String savedSsid = wifiPrefs.getString("ssid", "");
    String savedPassword = wifiPrefs.getString("password", "");
    wifiPrefs.end();

    WiFi.mode(WIFI_STA);
    WiFi.disconnect(true, false);
    delay(100);

    // Try saved WiFi first if configured
    if (savedSsid.length() > 0)
    {
        if (connectToWiFiNetwork(savedSsid, savedPassword, 15000))
        {
            return true;
        }
        delay(500);
        WiFi.disconnect(true, false);
        delay(100);
    }

    // Try primary WiFi (vivo)
    if (connectToWiFiNetwork(String(WIFI_SSID_PRIMARY), String(WIFI_PASSWORD_PRIMARY), 15000))
    {
        return true;
    }
    delay(500);
    WiFi.disconnect(true, false);
    delay(100);

    // Try fallback WiFi (Student)
    if (connectToWiFiNetwork(String(WIFI_SSID_FALLBACK), String(WIFI_PASSWORD_FALLBACK), 15000))
    {
        return true;
    }

    Serial.println(F("All WiFi connection attempts failed"));
    return false;
}

float readAverage(int pin)
{
    long sum = 0;
    for (int i = 0; i < SENSOR_SAMPLES; i++)
    {
        sum += analogRead(pin);
        delay(3);
    }
    return sum / (float)SENSOR_SAMPLES;
}

float readTemperature()
{
    tempSensor.requestTemperatures();
    float temp = tempSensor.getTempCByIndex(0);
    if (temp == DEVICE_DISCONNECTED_C)
    {
        Serial.println(F("Temperature sensor disconnected"));
        return -999.0f;
    }
    return temp;
}

float calculateNTU(float voltage)
{
    // Keep calibration values sane even if user enters bad data.
    float vClear = turbClearVoltage;
    float vDirty = turbDirtyVoltage;
    if (vClear <= vDirty + 0.05f)
    {
        vClear = 1.60f;
        vDirty = 0.60f;
    }

    if (voltage >= vClear - 0.02f)
    {
        return 0.0f;
    }
    if (voltage <= vDirty + 0.02f)
    {
        return 3000.0f;
    }

    // Linear interpolation with floating-point precision
    // voltage range [vDirty, vClear] maps to NTU range [3000, 0]
    float ntu = 3000.0f - (voltage - vDirty) / (vClear - vDirty) * 3000.0f;
    return constrain(ntu, 0.0f, 3000.0f);
}

float calculateTDS(float voltage, float temperatureC)
{
    float tempForComp = temperatureC;
    // Handle sensor error and out-of-range values
    if (tempForComp < -20.0f || tempForComp > 125.0f || tempForComp < -900.0f)
    {
        tempForComp = 25.0f;
    }

    float tempCompFactor = 1.0f + tdsTempCoeff * (tempForComp - 25.0f);
    if (tempCompFactor < 0.1f)
    {
        tempCompFactor = 0.1f;
    }

    float compensatedVoltage = voltage / tempCompFactor;
    float ppm = (133.42f * compensatedVoltage * compensatedVoltage * compensatedVoltage -
                 255.86f * compensatedVoltage * compensatedVoltage +
                 857.39f * compensatedVoltage) *
                0.5f;
    ppm *= tdsScaleFactor;
    return constrain(ppm, 0.0f, 2000.0f);
}

float calculatepH(float voltage)
{
    float slope = phSlope;
    if (slope > -0.01f && slope < 0.01f)
    {
        slope = -0.059f;
    }

    if (voltage < 0.0f || voltage > 3.3f)
    {
        return 7.0f;
    }

    float ph = 7.0f + (voltage - ph7Voltage) / slope;
    return constrain(ph, 0.0f, 14.0f);
}

void setPh7FromCurrentVoltage()
{
    float phRaw = readAverage(PH_PIN);
    float phVolt = phRaw * (3.3f / 4095.0f);

    if (phVolt < 0.0f || phVolt > 3.3f)
    {
        Serial.println(F("PH7 capture failed: voltage out of range"));
        return;
    }

    ph7Voltage = phVolt;
    Serial.print(F("PH7 captured from current voltage: "));
    Serial.println(ph7Voltage, 4);
    Serial.println(F("If this is neutral water/buffer, run SAVE"));
}

void setTurbClearFromCurrentVoltage()
{
    float turbRaw = readAverage(TURB_PIN);
    float turbVolt = turbRaw * (3.3f / 4095.0f);

    if (turbVolt < 0.0f || turbVolt > 3.3f)
    {
        Serial.println(F("TURB_CLEAR capture failed: voltage out of range"));
        return;
    }

    turbClearVoltage = turbVolt;
    Serial.print(F("TURB_CLEAR captured from current voltage: "));
    Serial.println(turbClearVoltage, 4);
    Serial.println(F("Sensor is in clean water. Run TURB_DIRTY_NOW for dirty reference, then SAVE"));
}

void setTurbDirtyFromCurrentVoltage()
{
    float turbRaw = readAverage(TURB_PIN);
    float turbVolt = turbRaw * (3.3f / 4095.0f);

    if (turbVolt < 0.0f || turbVolt > 3.3f)
    {
        Serial.println(F("TURB_DIRTY capture failed: voltage out of range"));
        return;
    }

    turbDirtyVoltage = turbVolt;
    Serial.print(F("TURB_DIRTY captured from current voltage: "));
    Serial.println(turbDirtyVoltage, 4);
    Serial.println(F("Both turbidity references set. Run SAVE to store calibration"));
}

String getTurbidityCategory(float ntu)
{
    if (ntu <= 5.0f)
    {
        return "Clear";
    }
    return "Murky";
}

String getTDSSalinity(float ppm)
{
    if (ppm <= 300)
    {
        return "Fresh";
    }
    if (ppm <= 1500)
    {
        return "Moderate salinity";
    }
    return "High salinity";
}

String getpHCategory(float ph)
{
    if (ph < 7.0f)
    {
        return "Acidic";
    }
    if (ph == 7.0f)
    {
        return "Neutral";
    }
    return "Alkaline";
}

void resetCalibrationToDefaults()
{
    ph7Voltage = 2.075f;
    phSlope = -0.059f;
    turbClearVoltage = 1.60f;
    turbDirtyVoltage = 0.60f;
    tdsScaleFactor = 1.0f;
    tdsTempCoeff = 0.02f;
}

void loadCalibration()
{
    calibrationPrefs.begin(CALIBRATION_NAMESPACE, true);
    uint32_t magic = calibrationPrefs.getUInt("magic", 0);

    if (magic != CALIBRATION_MAGIC)
    {
        calibrationPrefs.end();
        resetCalibrationToDefaults();
        saveCalibration();
        Serial.println(F("Calibration initialized with defaults"));
        return;
    }

    ph7Voltage = calibrationPrefs.getFloat("ph7v", 2.075f);
    phSlope = calibrationPrefs.getFloat("phSlope", -0.059f);
    turbClearVoltage = calibrationPrefs.getFloat("tClr", 1.60f);
    turbDirtyVoltage = calibrationPrefs.getFloat("tDrt", 0.60f);
    tdsScaleFactor = calibrationPrefs.getFloat("tdsK", 1.0f);
    tdsTempCoeff = calibrationPrefs.getFloat("tdsTC", 0.02f);
    calibrationPrefs.end();

    Serial.println(F("Calibration loaded from NVS"));
}

void saveCalibration()
{
    calibrationPrefs.begin(CALIBRATION_NAMESPACE, false);
    calibrationPrefs.putUInt("magic", CALIBRATION_MAGIC);
    calibrationPrefs.putFloat("ph7v", ph7Voltage);
    calibrationPrefs.putFloat("phSlope", phSlope);
    calibrationPrefs.putFloat("tClr", turbClearVoltage);
    calibrationPrefs.putFloat("tDrt", turbDirtyVoltage);
    calibrationPrefs.putFloat("tdsK", tdsScaleFactor);
    calibrationPrefs.putFloat("tdsTC", tdsTempCoeff);
    calibrationPrefs.end();
    Serial.println(F("Calibration saved"));
}

void printCalibration()
{
    Serial.println(F("--- Calibration ---"));
    Serial.print(F("PH7_VOLTAGE="));
    Serial.println(ph7Voltage, 4);
    Serial.print(F("PH_SLOPE="));
    Serial.println(phSlope, 4);
    Serial.print(F("TURB_CLEAR_V="));
    Serial.println(turbClearVoltage, 4);
    Serial.print(F("TURB_DIRTY_V="));
    Serial.println(turbDirtyVoltage, 4);
    Serial.print(F("TDS_FACTOR="));
    Serial.println(tdsScaleFactor, 4);
    Serial.print(F("TDS_TEMP_COEFF="));
    Serial.println(tdsTempCoeff, 4);
}

void printCalibrationHelp()
{
    Serial.println(F("Commands:"));
    Serial.println(F("  HELP"));
    Serial.println(F("  SHOW"));
    Serial.println(F("  SAVE"));
    Serial.println(F("  REBOOT"));
    Serial.println(F("  RESETCAL"));
    Serial.println(F("  PH7NOW"));
    Serial.println(F("  TURB_CLEAR_NOW"));
    Serial.println(F("  TURB_DIRTY_NOW"));
    Serial.println(F("  PH7 <voltage>"));
    Serial.println(F("  PHSLOPE <voltage_per_ph>"));
    Serial.println(F("  PH2PT <ph1> <v1> <ph2> <v2>"));
    Serial.println(F("  PH47 <v4> <v7>"));
    Serial.println(F("  TURB_CLEAR <voltage>"));
    Serial.println(F("  TURB_DIRTY <voltage>"));
    Serial.println(F("  TDS_FACTOR <multiplier>"));
    Serial.println(F("  TDS_TC <temp_coeff_per_C>"));
    Serial.println(F("  TESTBACKEND"));
}

bool applyTwoPointPhCalibration(float phA, float vA, float phB, float vB)
{
    if (phA < 0.0f || phA > 14.0f || phB < 0.0f || phB > 14.0f)
    {
        Serial.println(F("pH points must be 0-14"));
        return false;
    }

    if (vA < 0.0f || vA > 3.3f || vB < 0.0f || vB > 3.3f)
    {
        Serial.println(F("Voltage points must be 0.0-3.3"));
        return false;
    }

    float dPh = phB - phA;
    if (fabsf(dPh) < 0.1f)
    {
        Serial.println(F("pH points too close"));
        return false;
    }

    float newSlope = (vB - vA) / dPh;
    if (newSlope >= -0.01f || newSlope <= -0.2f)
    {
        Serial.println(F("Computed slope out of range. Recheck points"));
        return false;
    }

    float newPh7 = vA - newSlope * (phA - 7.0f);
    if (newPh7 < 0.0f || newPh7 > 3.3f)
    {
        Serial.println(F("Computed PH7 out of range"));
        return false;
    }

    phSlope = newSlope;
    ph7Voltage = newPh7;

    Serial.println(F("Two-point pH calibration applied"));
    Serial.print(F("PH7_VOLTAGE="));
    Serial.println(ph7Voltage, 4);
    Serial.print(F("PH_SLOPE="));
    Serial.println(phSlope, 4);
    return true;
}

// Scoring helper functions for water quality assessment
float score_pH(float ph)
{
    if (ph >= 7.0f && ph <= 7.5f)
        return 100.0f;
    if (ph >= 6.5f && ph < 7.0f)
        return 60.0f + (ph - 6.5f) * 80.0f; // 6.5->60 to 7.0->100
    if (ph > 7.5f && ph <= 8.5f)
        return 100.0f - (ph - 7.5f) * 40.0f; // 7.5->100 to 8.5->60
    if (ph >= 6.0f && ph < 6.5f)
        return 40.0f + (ph - 6.0f) * 40.0f; // 6.0->40 to 6.5->60
    if (ph > 8.5f && ph <= 9.0f)
        return 60.0f - (ph - 8.5f) * 40.0f; // 8.5->60 to 9.0->40
    return 20.0f;                           // outside safe band
}

float score_TDS(float tds)
{
    if (tds <= 300.0f)
        return 100.0f;
    if (tds <= 500.0f)
        return 100.0f - (tds - 300.0f) * (20.0f / 200.0f);
    if (tds <= 1000.0f)
        return 80.0f - (tds - 500.0f) * (20.0f / 500.0f);
    if (tds <= 2000.0f)
        return 60.0f - (tds - 1000.0f) * (30.0f / 1000.0f);
    if (tds <= 3000.0f)
        return 30.0f - (tds - 2000.0f) * (10.0f / 1000.0f);
    return 10.0f;
}

float score_Turbidity(float turb)
{
    if (turb <= 1.0f)
        return 100.0f;
    if (turb <= 5.0f)
        return 100.0f - (turb - 1.0f) * (20.0f / 4.0f);
    if (turb <= 50.0f)
        return 80.0f - (turb - 5.0f) * (30.0f / 45.0f);
    return 10.0f - (turb - 50.0f) * (10.0f / 450.0f);
}

float score_Temperature(float temp)
{
    if (temp >= 15.0f && temp <= 28.0f)
        return 100.0f;
    if (temp >= 10.0f && temp < 15.0f)
        return 60.0f + (temp - 10.0f) * (40.0f / 5.0f);
    if (temp > 28.0f && temp <= 32.0f)
        return 100.0f - (temp - 28.0f) * (30.0f / 4.0f);
    if (temp > 32.0f && temp <= 40.0f)
        return 70.0f - (temp - 32.0f) * (40.0f / 8.0f);
    return 10.0f;
}

void assessWaterQuality(float turbidity, float tds, float ph, float temperature, float &outWQI, String &outCategory, String &outAdvice)
{
    // Critical immediate reject conditions
    if (ph < 6.0f || ph > 9.0f || tds > 3000.0f || turbidity > 50.0f || temperature > 40.0f || temperature < 0.0f)
    {
        outCategory = "Too Dirty / Not Recommended";
        outAdvice = "High risk. Avoid for drinking or personal use. Use only for non-sensitive tasks or find alternative source. Treat and lab-test.";
        outWQI = 0.0f;
        return;
    }

    // If all parameters comfortably within Category 1 thresholds
    bool cat1 = (ph >= SAFE_PH_LOW && ph <= SAFE_PH_HIGH && tds <= DRINKABLE_TDS_MAX && turbidity <= DRINKABLE_TURBIDITY_MAX && temperature <= MAX_TEMPERATURE_DRINK);
    if (cat1)
    {
        outCategory = "Potentially Drinkable After Treatment";
        outAdvice = "Good physical parameters. Filter (sediment + activated carbon) and disinfect (boil/UV/chlorine) before drinking. Still recommended to lab-test.";
        // Cold water warning
        if (temperature < 10.0f)
        {
            outAdvice += " (Cold water: disinfection will be slower—use extended contact times)";
        }
        // Compute WQI for logging
        float qph = score_pH(ph);
        float qtds = score_TDS(tds);
        float qturb = score_Turbidity(turbidity);
        float qtemp = score_Temperature(temperature);
        outWQI = qph * WQI_WEIGHT_PH + qtds * WQI_WEIGHT_TDS + qturb * WQI_WEIGHT_TURBIDITY + qtemp * WQI_WEIGHT_TEMPERATURE;
        return;
    }

    // If within washing thresholds => Category 2
    bool cat2 = (ph >= 6.0f && ph <= 9.0f && tds <= WASH_TDS_MAX && turbidity <= WASH_TURBIDITY_MAX && temperature <= MAX_TEMPERATURE_WASH);

    // Compute WQI regardless
    float qph = score_pH(ph);
    float qtds = score_TDS(tds);
    float qturb = score_Turbidity(turbidity);
    float qtemp = score_Temperature(temperature);
    outWQI = qph * WQI_WEIGHT_PH + qtds * WQI_WEIGHT_TDS + qturb * WQI_WEIGHT_TURBIDITY + qtemp * WQI_WEIGHT_TEMPERATURE;

    if (cat2)
    {
        outCategory = "Safe for Washing / Bathing / Cleaning";
        outAdvice = "Suitable for laundry, dishwashing, and bathing. Pre-filter if turbid. May leave residue; use extra detergent/softener if TDS high. Not recommended for drinking without advanced treatment.";
        // Cold water warning
        if (temperature < 10.0f)
        {
            outAdvice += " (Cold water detected)";
        }
        return;
    }

    // Marginal handling based on WQI
    if (outWQI >= 60.0f)
    {
        outCategory = "Marginal - Limited Use";
        outAdvice = "Marginal quality. Best for rough cleaning (floors, car, non-contact uses). Avoid for clothes/dishes if possible. Do not drink.";
        return;
    }

    outCategory = "Too Dirty / Not Recommended";
    outAdvice = "High risk. Too dirty for most uses. Avoid and find alternate source. Treat and lab-test.";
    return;
}

void updateFirebase(
    float turbidityRaw,
    float tdsRaw,
    float phRaw,
    float temperature,
    float ph7Voltage,
    float phSlope,
    float turbClearVoltage,
    float turbDirtyVoltage,
    float tdsScaleFactor,
    float tdsTempCoeff,
    float wqi,
    const String &category,
    const String &advice)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        return;
    }

    if (ESP.getFreeHeap() < MIN_FREE_HEAP_FOR_HTTP)
    {
        Serial.print(F("Skipping Firebase update, low heap: "));
        Serial.println(ESP.getFreeHeap());
        return;
    }

    StaticJsonDocument<768> doc;
    doc["rawTurbidity"] = turbidityRaw;
    doc["rawTds"] = tdsRaw;
    doc["rawPh"] = phRaw;
    doc["temperature"] = temperature;
    doc["ph7Voltage"] = ph7Voltage;
    doc["phSlope"] = phSlope;
    doc["turbClearVoltage"] = turbClearVoltage;
    doc["turbDirtyVoltage"] = turbDirtyVoltage;
    doc["tdsScaleFactor"] = tdsScaleFactor;
    doc["tdsTempCoeff"] = tdsTempCoeff;
    doc["source"] = "esp32";
    doc["updatedAt"] = millis();

    // Assessment fields
    doc["wqi"] = wqi;
    doc["category"] = category.c_str();
    doc["advice"] = advice.c_str();

    String payload;
    serializeJson(doc, payload);

    HTTPClient http;
    http.setReuse(false);
    http.setConnectTimeout(7000);
    http.setTimeout(10000);

    // If configured, send directly to Firebase Realtime Database
    if (String(FIREBASE_DATABASE_URL).length() > 0)
    {
        String fbUrl = String(FIREBASE_DATABASE_URL) + "/sensors.json";
        if (String(FIREBASE_DATABASE_AUTH).length() > 0)
        {
            fbUrl += "?auth=" + String(FIREBASE_DATABASE_AUTH);
        }

        if (!http.begin(fbUrl))
        {
            Serial.println(F("Firebase HTTP begin failed"));
            return;
        }

        http.addHeader("Content-Type", "application/json");
        int code = http.POST(payload);
        if (code == 200 || code == 201)
        {
            Serial.println(F("Firebase ingest updated"));
        }
        else
        {
            Serial.print(F("Firebase ingest failed: "));
            Serial.println(code);
            String response = http.getString();
            if (response.length() > 0)
            {
                Serial.println(response);
            }
        }

        http.end();
        return;
    }

    // Fallback: send to backend ingest endpoint
    String httpsUrl = String(BACKEND_BASE_URL) + BACKEND_INGEST_PATH;
    String httpUrl = "http://waterguard-server.onrender.com" + String(BACKEND_INGEST_PATH);

    // Verify WiFi is still connected
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println(F("WiFi disconnected during backend update"));
        return;
    }

    // Try HTTPS first with secure client
    {
        WiFiClientSecure *client = new WiFiClientSecure;
        if (client)
        {
            client->setInsecure();

            if (http.begin(*client, httpsUrl))
            {
                http.addHeader("Content-Type", "application/json");
                if (String(BACKEND_INGEST_KEY).length() > 0)
                {
                    http.addHeader("x-ingest-key", String(BACKEND_INGEST_KEY));
                }

                int code = http.POST(payload);
                if (code == 200 || code == 201)
                {
                    Serial.println(F("Backend ingest updated (HTTPS)"));
                    http.end();
                    delete client;
                    return;
                }
                else if (code != -1 && code != 0)
                {
                    // Got a response (even if error), HTTPS is working
                    Serial.print(F("Backend HTTPS response: "));
                    Serial.println(code);
                    http.end();
                    delete client;
                    return;
                }

                http.end();
            }
            else
            {
                Serial.println(F("HTTPS begin failed, trying HTTP fallback"));
            }

            delete client;
        }
    }

    // Fallback to HTTP if HTTPS fails
    Serial.println(F("Attempting HTTP fallback..."));
    WiFiClient *httpClient = new WiFiClient;
    if (httpClient && http.begin(*httpClient, httpUrl))
    {
        http.addHeader("Content-Type", "application/json");
        if (String(BACKEND_INGEST_KEY).length() > 0)
        {
            http.addHeader("x-ingest-key", String(BACKEND_INGEST_KEY));
        }

        int code = http.POST(payload);
        if (code == 200 || code == 201)
        {
            Serial.println(F("Backend ingest updated (HTTP fallback)"));
        }
        else if (code == 307 || code == 301 || code == 302)
        {
            Serial.print(F("Redirect response: "));
            Serial.println(code);
            Serial.println(F("Note: Redirect detected but not followed (HTTP fallback has limitations)"));
            // Redirects are not automatically followed in fallback mode to prevent crashes
            // Backend may have moved the endpoint
            String response = http.getString(); // Consume response to avoid memory issues
        }
        else if (code == -1)
        {
            Serial.println(F("Backend ingest failed (-1): Check DNS/firewall"));
            Serial.print(F("Heap available: "));
            Serial.println(ESP.getFreeHeap());
        }
        else if (code == 0)
        {
            Serial.println(F("Backend ingest failed (0): No response - backend may be down"));
        }
        else
        {
            Serial.print(F("Backend HTTP response: "));
            Serial.println(code);
            String response = http.getString(); // Consume response
        }

        http.end();
    }
    else
    {
        Serial.println(F("Failed to create HTTP client"));
    }

    if (httpClient)
    {
        delete httpClient;
    }
}

void processSerialCommands()
{
    if (!Serial.available())
    {
        return;
    }

    String raw = Serial.readStringUntil('\n');
    raw.trim();
    if (raw.length() == 0)
    {
        return;
    }

    String cmd = raw;
    cmd.toUpperCase();

    if (cmd == "TESTBACKEND")
    {
        if (WiFi.status() != WL_CONNECTED)
        {
            Serial.println(F("WiFi not connected"));
            return;
        }

        Serial.println(F("=== Backend Connectivity Test ==="));
        Serial.print(F("Endpoint: POST "));
        Serial.println(String(BACKEND_BASE_URL) + BACKEND_INGEST_PATH);

        // Test DNS resolution
        Serial.print(F("1. DNS Resolution ... "));
        IPAddress ip;
        int dnsResult = WiFi.hostByName("waterguard-server.onrender.com", ip);
        if (dnsResult == 0)
        {
            Serial.println(F("FAILED"));
            return;
        }
        else
        {
            Serial.println(F("OK"));
        }

        // Create test payload
        StaticJsonDocument<512> testDoc;
        testDoc["rawTurbidity"] = 2048;
        testDoc["rawTds"] = 2048;
        testDoc["rawPh"] = 2048;
        testDoc["temperature"] = 25.5;
        testDoc["ph7Voltage"] = 2.075;
        testDoc["phSlope"] = -0.059;
        testDoc["turbClearVoltage"] = 1.60;
        testDoc["turbDirtyVoltage"] = 0.60;
        testDoc["tdsScaleFactor"] = 1.0;
        testDoc["tdsTempCoeff"] = 0.02;
        testDoc["source"] = "esp32-test";
        testDoc["updatedAt"] = millis();

        String testPayload;
        serializeJson(testDoc, testPayload);

        // Test HTTPS POST
        Serial.print(F("2. HTTPS POST ... "));
        WiFiClientSecure *secureClient = new WiFiClientSecure;
        secureClient->setInsecure();

        HTTPClient httpsHttp;
        String httpsUrl = String(BACKEND_BASE_URL) + BACKEND_INGEST_PATH;

        if (httpsHttp.begin(*secureClient, httpsUrl))
        {
            httpsHttp.addHeader("Content-Type", "application/json");
            if (String(BACKEND_INGEST_KEY).length() > 0)
            {
                httpsHttp.addHeader("x-ingest-key", String(BACKEND_INGEST_KEY));
            }

            int code = httpsHttp.POST(testPayload);
            Serial.print(F("Response: "));
            Serial.println(code);

            if (code == 200 || code == 201)
            {
                Serial.println(F("SUCCESS! Backend is ready to receive data."));
                httpsHttp.end();
                delete secureClient;
                return;
            }

            httpsHttp.end();
        }
        else
        {
            Serial.println(F("begin failed"));
        }

        delete secureClient;

        // Test HTTP fallback
        Serial.print(F("3. HTTP POST fallback ... "));
        WiFiClient *httpClient = new WiFiClient;
        HTTPClient httpHttp;
        String httpUrl = "http://waterguard-server.onrender.com" + String(BACKEND_INGEST_PATH);

        if (httpHttp.begin(*httpClient, httpUrl))
        {
            httpHttp.addHeader("Content-Type", "application/json");
            if (String(BACKEND_INGEST_KEY).length() > 0)
            {
                httpHttp.addHeader("x-ingest-key", String(BACKEND_INGEST_KEY));
            }

            int code = httpHttp.POST(testPayload);
            Serial.print(F("Response: "));
            Serial.println(code);

            if (code == 200 || code == 201)
            {
                Serial.println(F("SUCCESS! Backend is ready (HTTP)."));
            }

            httpHttp.end();
        }
        else
        {
            Serial.println(F("begin failed"));
        }

        delete httpClient;

        Serial.println(F("=== Test Complete ==="));
        return;
    }

    if (cmd.startsWith("PH2PT "))
    {
        float ph1 = 0.0f;
        float v1 = 0.0f;
        float ph2 = 0.0f;
        float v2 = 0.0f;
        int parsed = sscanf(cmd.c_str(), "PH2PT %f %f %f %f", &ph1, &v1, &ph2, &v2);
        if (parsed != 4)
        {
            Serial.println(F("Usage: PH2PT <ph1> <v1> <ph2> <v2>"));
            return;
        }
        applyTwoPointPhCalibration(ph1, v1, ph2, v2);
        return;
    }

    if (cmd.startsWith("PH47 "))
    {
        float v4 = 0.0f;
        float v7 = 0.0f;
        int parsed = sscanf(cmd.c_str(), "PH47 %f %f", &v4, &v7);
        if (parsed != 2)
        {
            Serial.println(F("Usage: PH47 <v4> <v7>"));
            return;
        }
        applyTwoPointPhCalibration(4.0f, v4, 7.0f, v7);
        return;
    }

    if (cmd == "HELP")
    {
        printCalibrationHelp();
        return;
    }
    if (cmd == "SHOW")
    {
        printCalibration();
        return;
    }
    if (cmd == "SAVE")
    {
        saveCalibration();
        return;
    }
    if (cmd == "REBOOT")
    {
        Serial.println(F("Rebooting..."));
        delay(100);
        ESP.restart();
        return;
    }
    if (cmd == "RESETCAL")
    {
        resetCalibrationToDefaults();
        saveCalibration();
        printCalibration();
        return;
    }
    if (cmd == "PH7NOW")
    {
        setPh7FromCurrentVoltage();
        return;
    }

    if (cmd == "TURB_CLEAR_NOW")
    {
        setTurbClearFromCurrentVoltage();
        return;
    }

    if (cmd == "TURB_DIRTY_NOW")
    {
        setTurbDirtyFromCurrentVoltage();
        return;
    }

    int splitAt = cmd.indexOf(' ');
    if (splitAt < 0)
    {
        Serial.println(F("Unknown command. Type HELP"));
        return;
    }

    String key = cmd.substring(0, splitAt);
    String valuePart = cmd.substring(splitAt + 1);
    valuePart.trim();
    float value = valuePart.toFloat();

    if (key == "PH7")
    {
        if (value < 0.0f || value > 3.3f)
        {
            Serial.println(F("PH7 must be 0.0-3.3"));
            return;
        }
        ph7Voltage = value;
        Serial.println(F("PH7 updated"));
        return;
    }

    if (key == "PHSLOPE")
    {
        if (value > -0.01f || value < -0.2f)
        {
            Serial.println(F("PHSLOPE must be between -0.2 and -0.01"));
            return;
        }
        phSlope = value;
        Serial.println(F("PHSLOPE updated"));
        return;
    }

    if (key == "TURB_CLEAR")
    {
        if (value < 0.2f || value > 3.3f)
        {
            Serial.println(F("TURB_CLEAR must be 0.2-3.3"));
            return;
        }
        turbClearVoltage = value;
        Serial.println(F("TURB_CLEAR updated"));
        return;
    }

    if (key == "TURB_DIRTY")
    {
        if (value < 0.0f || value > 3.0f)
        {
            Serial.println(F("TURB_DIRTY must be 0.0-3.0"));
            return;
        }
        turbDirtyVoltage = value;
        Serial.println(F("TURB_DIRTY updated"));
        return;
    }

    if (key == "TDS_FACTOR")
    {
        if (value <= 0.1f || value > 5.0f)
        {
            Serial.println(F("TDS_FACTOR must be >0.1 and <=5.0"));
            return;
        }
        tdsScaleFactor = value;
        Serial.println(F("TDS_FACTOR updated"));
        return;
    }

    if (key == "TDS_TC")
    {
        if (value < 0.0f || value > 0.1f)
        {
            Serial.println(F("TDS_TC must be 0.0-0.1"));
            return;
        }
        tdsTempCoeff = value;
        Serial.println(F("TDS_TC updated"));
        return;
    }

    Serial.println(F("Unknown command. Type HELP"));
}

void setup()
{
    Serial.begin(115200);
    delay(300);

    Serial.println();
    Serial.print(F("Reset reason code: "));
    Serial.println((int)esp_reset_reason());

    pinMode(PH_PIN, INPUT);
    pinMode(TURB_PIN, INPUT);
    pinMode(TDS_PIN, INPUT);
    pinMode(TEMP_PIN, INPUT);

    tempSensor.begin();
    Serial.println(F("Temperature sensor initialized"));

    loadCalibration();
    printCalibration();
    printCalibrationHelp();

    // Check if setup mode should be started (first boot or button press)
    // For now, always try to connect to WiFi, but if it fails, start setup mode
    if (!connectToWiFi())
    {
        Serial.println(F("WiFi connection failed, starting setup mode"));
        startSetupMode();
    }
}

// ============ WiFi Setup Mode Implementation ============

void startSetupMode()
{
    Serial.println(F("=== Starting Setup Mode ==="));
    isInSetupMode = true;
    setupModeStartTime = millis();

    // Disconnect from normal WiFi
    WiFi.mode(WIFI_OFF);
    delay(100);

    // Start AP mode
    WiFi.mode(WIFI_AP);
    WiFi.softAPConfig(SETUP_AP_IP, SETUP_AP_GATEWAY, SETUP_AP_SUBNET);
    WiFi.softAP(SETUP_AP_SSID, SETUP_AP_PASSWORD);

    Serial.print(F("Setup AP started: "));
    Serial.println(SETUP_AP_SSID);
    Serial.print(F("IP: "));
    Serial.println(WiFi.softAPIP());
    Serial.println(F("Connect phone to WaterGuard-Setup to configure WiFi"));

    // Initialize and start the setup server
    initSetupServer();
}

void stopSetupMode()
{
    Serial.println(F("=== Stopping Setup Mode ==="));
    isInSetupMode = false;
    setupServer.stop();
    WiFi.mode(WIFI_OFF);
    delay(100);
}

void initSetupServer()
{
    // Register routes
    setupServer.on("/scan-wifi", HTTP_GET, handleScanWifi);
    setupServer.on("/wifi-status", HTTP_GET, handleWifiStatus);
    setupServer.on("/configure-wifi", HTTP_POST, handleConfigureWifi);
    setupServer.on("/connect-wifi", HTTP_POST, handleConnectWifi);
    setupServer.on("/start-setup-mode", HTTP_POST, handleStartSetupMode);

    // Catch-all for debugging
    setupServer.onNotFound([]()
                           {
        Serial.print(F("Unknown request: "));
        Serial.println(setupServer.uri());
        setupServer.send(404, "text/plain", "Endpoint not found"); });

    // Start the server
    setupServer.begin();
    Serial.println(F("Setup server started on port 80"));
}

void handleScanWifi()
{
    Serial.println(F("Scanning WiFi networks..."));

    int n = WiFi.scanNetworks();
    Serial.print(F("Found "));
    Serial.print(n);
    Serial.println(F(" networks"));

    StaticJsonDocument<2048> doc;
    JsonArray networks = doc.createNestedArray("networks");

    for (int i = 0; i < n; ++i)
    {
        JsonObject net = networks.createNestedObject();
        net["ssid"] = WiFi.SSID(i).c_str();
        net["rssi"] = WiFi.RSSI(i);
        net["secure"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
    }

    String response;
    serializeJson(doc, response);
    setupServer.send(200, "application/json", response);
}

void handleWifiStatus()
{
    StaticJsonDocument<256> doc;

    if (isInSetupMode)
    {
        // In AP mode
        doc["connected"] = false;
        doc["currentSsid"] = "";
        doc["savedSsid"] = "";
        doc["connecting"] = false;
        doc["connectingToSsid"] = "";
    }
    else
    {
        // In STA mode
        wl_status_t status = WiFi.status();
        doc["connected"] = (status == WL_CONNECTED);
        doc["currentSsid"] = WiFi.SSID().c_str();
        doc["savedSsid"] = String(WIFI_SSID_PRIMARY).c_str();
        doc["connecting"] = (status == WL_CONNECT_FAILED || status == WL_DISCONNECTED);
        doc["connectingToSsid"] = "";
    }

    String response;
    serializeJson(doc, response);
    setupServer.send(200, "application/json", response);
}

void handleConfigureWifi()
{
    String payload = setupServer.arg("plain");
    Serial.print(F("Configure WiFi payload: "));
    Serial.println(payload);

    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (error)
    {
        Serial.print(F("JSON parse error: "));
        Serial.println(error.c_str());
        setupServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
        return;
    }

    String ssid = doc["ssid"] | "";
    String password = doc["password"] | "";

    if (ssid.length() == 0)
    {
        setupServer.send(400, "application/json", "{\"error\":\"SSID required\"}");
        return;
    }

    Serial.print(F("Configuring WiFi: SSID="));
    Serial.print(ssid);
    Serial.print(F(" (password length: "));
    Serial.print(password.length());
    Serial.println(F(")"));

    // Save to Preferences for next boot
    Preferences prefs;
    prefs.begin("wifi_config", false);
    prefs.putString("ssid", ssid);
    prefs.putString("password", password);
    prefs.end();

    setupServer.send(200, "application/json", "{\"status\":\"configured\"}");
    shouldRestartAfterConfig = true;
}

void handleConnectWifi()
{
    String payload = setupServer.arg("plain");
    Serial.print(F("Connect WiFi payload: "));
    Serial.println(payload);

    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (error)
    {
        Serial.print(F("JSON parse error: "));
        Serial.println(error.c_str());
        setupServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
        return;
    }

    String ssid = doc["ssid"] | "";
    String password = doc["password"] | "";

    if (ssid.length() == 0)
    {
        setupServer.send(400, "application/json", "{\"error\":\"SSID required\"}");
        return;
    }

    Serial.print(F("Connecting to WiFi: "));
    Serial.println(ssid);

    // Save and connect immediately
    Preferences prefs;
    prefs.begin("wifi_config", false);
    prefs.putString("ssid", ssid);
    prefs.putString("password", password);
    prefs.end();

    setupServer.send(200, "application/json", "{\"status\":\"connecting\"}");
    shouldRestartAfterConfig = true;
}

void handleStartSetupMode()
{
    Serial.println(F("Setup mode requested"));
    setupServer.send(200, "application/json", "{\"status\":\"setup_mode_ready\"}");
    // Setup mode is already active since we got this request on the setup server
}

void checkSetupModeTimeout()
{
    if (isInSetupMode && millis() - setupModeStartTime > SETUP_MODE_TIMEOUT_MS)
    {
        Serial.println(F("Setup mode timeout, restarting"));
        stopSetupMode();
        delay(1000);
        ESP.restart();
    }
}

void checkAndReconnectWiFi()
{
    // Only check periodically to avoid excessive overhead
    if (millis() - lastWiFiCheckMs < WIFI_CHECK_INTERVAL_MS)
    {
        return;
    }
    lastWiFiCheckMs = millis();

    // If WiFi is connected, we're good
    if (WiFi.status() == WL_CONNECTED)
    {
        return;
    }

    // WiFi disconnected, attempt to reconnect
    Serial.println(F("WiFi disconnected! Attempting to reconnect..."));
    if (!connectToWiFi())
    {
        Serial.println(F("WiFi reconnection failed, starting setup mode"));
        startSetupMode();
    }
}

void loop()
{
    // Handle setup mode
    if (isInSetupMode)
    {
        setupServer.handleClient();
        checkSetupModeTimeout();

        if (shouldRestartAfterConfig)
        {
            Serial.println(F("Restarting after WiFi configuration..."));
            delay(2000);
            stopSetupMode();
            delay(500);
            ESP.restart();
        }

        delay(100);
        return;
    }

    processSerialCommands();

    // Check WiFi connection status and reconnect if needed
    checkAndReconnectWiFi();

    if (millis() - lastHeapLogMs > 30000)
    {
        Serial.print(F("[Heap] free="));
        Serial.print(ESP.getFreeHeap());
        Serial.print(F(" min="));
        Serial.println(ESP.getMinFreeHeap());
        lastHeapLogMs = millis();
    }

    float turbRaw = readAverage(TURB_PIN);
    float tdsRaw = readAverage(TDS_PIN);
    float phRaw = readAverage(PH_PIN);

    float turbVolt = turbRaw * (3.3f / 4095.0f);
    float tdsVolt = tdsRaw * (3.3f / 4095.0f);
    float phVolt = phRaw * (3.3f / 4095.0f);

    float temperature = readTemperature();
    float turbidity = calculateNTU(turbVolt);
    float tds = calculateTDS(tdsVolt, temperature);
    float phValue = calculatepH(phVolt);

    // Validate sensor readings for physically impossible values
    if (temperature < -999.0f || temperature > 100.0f || phValue < 0.0f || phValue > 14.0f || turbidity < 0.0f || tds < 0.0f)
    {
        Serial.println(F("Invalid sensor reading detected, skipping this cycle"));
        delay(SENSOR_CYCLE_DELAY_MS);
        return;
    }

    Serial.print(F("Turb: "));
    Serial.print((int)turbidity);
    Serial.print(F(" NTU ("));
    Serial.print(getTurbidityCategory(turbidity));
    Serial.print(F(") | "));
    Serial.print(F("TDS: "));
    Serial.print((int)tds);
    Serial.print(F(" ppm ("));
    Serial.print(getTDSSalinity(tds));
    Serial.print(F(") | pH: "));
    Serial.print(phValue, 2);
    Serial.print(F(" ("));
    Serial.print(getpHCategory(phValue));
    Serial.print(F(") | Temp: "));
    Serial.print(temperature, 1);
    Serial.println(F(" C"));

    if (millis() - lastFirebaseUpdateMs >= FIREBASE_UPDATE_INTERVAL_MS)
    {
        float wqi = 0.0f;
        String category = "";
        String advice = "";
        assessWaterQuality(turbidity, tds, phValue, temperature, wqi, category, advice);

        // Print concise assessment to serial
        Serial.print(F("WQI: "));
        Serial.print(wqi, 1);
        Serial.print(F(" | Category: "));
        Serial.print(category);
        Serial.print(F(" | Advice: "));
        Serial.println(advice);

        updateFirebase(
            turbRaw,
            tdsRaw,
            phRaw,
            temperature,
            ph7Voltage,
            phSlope,
            turbClearVoltage,
            turbDirtyVoltage,
            tdsScaleFactor,
            tdsTempCoeff,
            wqi,
            category,
            advice);
        lastFirebaseUpdateMs = millis();
    }

    unsigned long waitUntil = millis() + SENSOR_CYCLE_DELAY_MS;
    while (millis() < waitUntil)
    {
        processSerialCommands();
        delay(10);
    }
}