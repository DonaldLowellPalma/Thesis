/*
ESP32 LCD Assessment Example
Displays WQI, Category, and short advice on a 16x2 I2C LCD (LiquidCrystal_I2C)
Adapt this to your display (SSD1306, TFT) if needed.

Integration: Call `displayAssessment(wqi, category, advice)` from your main loop
after `assessWaterQuality(...)` runs.
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// I2C address may vary. Common is 0x27 or 0x3F.
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Simple helper to show truncated advice and auto-scroll long advice
void showScrollingAdvice(const String &advice)
{
    const int width = 16;
    if (advice.length() <= width)
    {
        lcd.setCursor(0, 1);
        lcd.print(advice);
        for (int i = advice.length(); i < width; ++i)
            lcd.print(' ');
        return;
    }

    // Scroll
    int len = advice.length();
    for (int pos = 0; pos <= len - width; ++pos)
    {
        lcd.setCursor(0, 1);
        lcd.print(advice.substring(pos, pos + width));
        delay(900);
    }
    // Small pause then show last segment
    delay(700);
}

void displayAssessment(float wqi, const String &category, const String &advice)
{
    lcd.clear();
    lcd.home();

    // Line 1: Category + WQI
    String line1 = "";
    if (wqi >= 0.0)
    {
        char buf[16];
        snprintf(buf, sizeof(buf), "WQI:%3.0f", wqi);
        line1 = String(buf) + " ";
    }
    line1 += category;
    if (line1.length() > 16)
        line1 = line1.substring(0, 16);

    lcd.setCursor(0, 0);
    lcd.print(line1);

    // Line 2: Advice (scroll if long)
    showScrollingAdvice(advice);
}

void setup()
{
    Wire.begin();
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WaterGuard v1");
    lcd.setCursor(0, 1);
    lcd.print("Initializing...");
    delay(1500);
}

void loop()
{
    // Demo values - replace with real values from sensors
    float demoWQI = 82.5;
    String demoCategory = "Safe for Washing";
    String demoAdvice = "Pre-filter if turbid. Not for drinking without advanced treatment.";

    displayAssessment(demoWQI, demoCategory, demoAdvice);
    delay(8000);

    // Show another demo
    demoWQI = 92.3;
    demoCategory = "Drink after treatment";
    demoAdvice = "Filter + boil/UV/chlorine before drinking. Lab-test recommended.";
    displayAssessment(demoWQI, demoCategory, demoAdvice);
    delay(8000);
}
