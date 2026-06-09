#!/usr/bin/env python3
import sys
import json
import os


def read_sensor_values(data):
    turb = float(data.get("turbidity") or data.get("turb") or 0)
    tds = float(data.get("tds") or 0)
    ph = float(data.get("phLevel") or data.get("ph") or 7)
    temperature = float(data.get("temperature") or 0)
    return turb, tds, ph, temperature


def build_signals(turb, tds, ph, temperature):
    signals = []

    if turb <= 30:
        signals.append("turbidity is low, so the water looks relatively clear")
    elif turb <= 120:
        signals.append("turbidity is moderate, which suggests some cloudiness")
    else:
        signals.append("turbidity is high, which suggests dirty or cloudy water")

    if tds <= 500:
        signals.append("TDS is low to moderate, which usually means fewer dissolved solids")
    elif tds <= 1500:
        signals.append("TDS is elevated, which can mean more dissolved salts or minerals")
    else:
        signals.append("TDS is very high, which often indicates poor water quality")

    if 6.5 <= ph <= 8.5:
        signals.append("pH is within the normal safe range (6.5–8.5)")
    else:
        if ph < 6.5:
            signals.append(f"pH is low ({ph:.2f}), water is acidic")
        else:
            signals.append(f"pH is high ({ph:.2f}), water is alkaline")

    if temperature > 0:
        signals.append(f"temperature is {temperature:.1f}°C")

    return signals


def build_explanation(classification, turb, tds, ph, temperature, score=None, method="model"):
    signals = build_signals(turb, tds, ph, temperature)
    # Lead sentence tailored to classification
    if classification == "safe":
        lead = "Assessment: readings are within acceptable limits."
    elif classification == "warning":
        lead = "Assessment: some readings are outside ideal ranges and merit attention."
    else:
        lead = "Assessment: one or more readings indicate unsafe water."

    parts = [lead]
    if score is not None:
        parts.append(f"Confidence: {score:.2f}.")

    # Add sensor-specific detail sentences
    details = []
    # Turbidity detail
    if turb <= 30:
        details.append(f"Turbidity is low ({turb:.1f} NTU) — water appears clear.")
    elif turb <= 120:
        details.append(f"Turbidity is moderate ({turb:.1f} NTU) — some cloudiness present.")
    else:
        details.append(f"Turbidity is high ({turb:.1f} NTU) — water is very cloudy/dirty.")

    # TDS detail
    if tds <= 500:
        details.append(f"TDS is {tds:.0f} ppm — dissolved solids are low to moderate.")
    elif tds <= 1500:
        details.append(f"TDS is {tds:.0f} ppm — elevated dissolved solids detected.")
    else:
        details.append(f"TDS is {tds:.0f} ppm — very high dissolved solids (poor quality).")

    # pH detail (already included in signals but keep structured)
    if 6.5 <= ph <= 8.5:
        details.append(f"pH is {ph:.2f}, within normal range.")
    else:
        details.append(f"pH is {ph:.2f}, outside normal range (6.5–8.5).")

    if temperature > 0:
        details.append(f"Temperature: {temperature:.1f}°C.")

    # Actionable recommendation
    recommendation = "No action needed." if classification == "safe" else (
        "Monitor the sensor and consider testing/filtration — avoid using the water for drinking until corrected." if classification == "warning" else
        "Stop using the water for drinking and apply treatment or source change; investigate causes immediately.")

    parts.append("Details: " + " ".join(details))
    if method == "rule_based":
        parts.append("(Note: explanation from simple rule-based fallback.)")

    return " ".join(parts), recommendation, signals

def rule_based_predict(data):
    turb, tds, ph, temperature = read_sensor_values(data)
    risk = 0.0
    if turb > 120:
        risk += 0.6
    elif turb > 30:
        risk += 0.3
    if tds > 1500:
        risk += 0.4
    if ph < 6.5 or ph > 8.5:
        risk += 0.3
    risk = min(1.0, risk)
    classification = "unsafe" if risk > 0.5 else ("warning" if risk > 0.2 else "safe")
    explanation, recommendation, signals = build_explanation(classification, turb, tds, ph, temperature, risk, "rule_based")
    return {
        "classification": classification,
        "risk": risk,
        "method": "rule_based",
        "explanation": explanation,
        "recommendation": recommendation,
        "signals": signals,
    }


def predict_with_model(data):
    try:
        import joblib
        model_path = os.path.join(os.path.dirname(__file__), "model.pkl")
        if not os.path.exists(model_path):
            return None
        model = joblib.load(model_path)
        # Expect features order: turbidity, tds, phLevel, temperature
        turb, tds, ph, temperature = read_sensor_values(data)
        features = [turb, tds, ph, temperature]
        pred = model.predict([features])[0]
        # If model supports predict_proba
        score = None
        try:
            probs = model.predict_proba([features])[0]
            # take max prob
            score = float(max(probs))
        except Exception:
            score = None
        classification = str(pred)
        explanation, recommendation, signals = build_explanation(classification, turb, tds, ph, temperature, score, "model")
        return {
            "classification": classification,
            "score": score,
            "method": "model",
            "explanation": explanation,
            "recommendation": recommendation,
            "signals": signals,
        }
    except Exception as e:
        return None


def main():
    try:
        raw = sys.stdin.read()
        if not raw:
            print(json.dumps({"error": "no input"}))
            sys.exit(1)
        data = json.loads(raw)
    except Exception as e:
        print(json.dumps({"error": "invalid json", "detail": str(e)}))
        sys.exit(1)

    # Try model first
    out = predict_with_model(data)
    if out is None:
        out = rule_based_predict(data)

    print(json.dumps(out))


if __name__ == "__main__":
    main()
