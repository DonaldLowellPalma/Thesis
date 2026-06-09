#!/usr/bin/env python3
"""
Generate a synthetic water quality training CSV.
Creates a file `water_quality_training_data.csv` with the following columns:
pH,TDS,Turbidity,Temperature,pH_score,TDS_score,Turbidity_score,Temp_score,WQI,Category,Recommended_Use,Safety_Advice,Risk_Level

Usage:
    python generate_synthetic_dataset.py --rows 500 --out water_quality_training_data.csv

The script implements conservative, safety-first rules aligned with the project's firmware logic.
"""
import csv
import argparse
import math

# Weights (match firmware)
WQI_WEIGHT_TURBIDITY = 0.40
WQI_WEIGHT_TDS = 0.30
WQI_WEIGHT_PH = 0.20
WQI_WEIGHT_TEMPERATURE = 0.10


def score_pH(ph):
    if 7.0 <= ph <= 7.5:
        return 100.0
    if 6.5 <= ph < 7.0:
        return 60.0 + (ph - 6.5) * 80.0
    if 7.5 < ph <= 8.5:
        return 100.0 - (ph - 7.5) * 40.0
    if 6.0 <= ph < 6.5:
        return 40.0 + (ph - 6.0) * 40.0
    if 8.5 < ph <= 9.0:
        return 60.0 - (ph - 8.5) * 40.0
    return 20.0


def score_TDS(tds):
    if tds <= 300.0:
        return 100.0
    if tds <= 500.0:
        return 100.0 - (tds - 300.0) * (20.0 / 200.0)
    if tds <= 1000.0:
        return 80.0 - (tds - 500.0) * (20.0 / 500.0)
    if tds <= 2000.0:
        return 60.0 - (tds - 1000.0) * (30.0 / 1000.0)
    if tds <= 3000.0:
        return 30.0 - (tds - 2000.0) * (10.0 / 1000.0)
    return 10.0


def score_Turbidity(turb):
    if turb <= 1.0:
        return 100.0
    if turb <= 5.0:
        return 100.0 - (turb - 1.0) * (20.0 / 4.0)
    if turb <= 10.0:
        return 80.0 - (turb - 5.0) * (30.0 / 5.0)
    if turb <= 30.0:
        return 50.0 - (turb - 10.0) * (30.0 / 20.0)
    if turb <= 50.0:
        return 20.0 - (turb - 30.0) * (20.0 / 20.0)
    return 0.0


def score_Temperature(temp):
    if 15.0 <= temp <= 28.0:
        return 100.0
    if 10.0 <= temp < 15.0:
        return 60.0 + (temp - 10.0) * (40.0 / 5.0)
    if 28.0 < temp <= 32.0:
        return 100.0 - (temp - 28.0) * (30.0 / 4.0)
    if 32.0 < temp <= 40.0:
        return 70.0 - (temp - 32.0) * (40.0 / 8.0)
    return 10.0


def label_from_values(ph, tds, turb, temp):
    # priority: critical reject
    if ph < 6.0 or ph > 9.0 or tds > 3000 or turb > 50 or temp > 40 or temp < 5:
        return 4, "Too dirty", "High risk. Avoid for drinking or personal use. Use only for non-sensitive tasks or find alternative source. Treat and lab-test.", "High"

    cat1 = (6.5 <= ph <= 8.5 and tds <= 600 and turb <= 5 and temp <= 32)
    if cat1:
        return 1, "Drink_after_treatment", "Good physical parameters. Filter + disinfect (boil/UV/chlorine) before drinking. Lab-test recommended.", "Low"

    cat2 = (6.0 <= ph <= 9.0 and tds <= 2000 and turb <= 30 and temp <= 40)
    if cat2:
        return 2, "Washing_safe", "Suitable for laundry, dishwashing, bathing. Pre-filter if turbid. Not recommended for drinking without advanced treatment.", "Medium"

    return 3, "Marginal", "Marginal quality. Best for rough cleaning (floors, car, non-contact uses). Avoid for clothes/dishes. Do not drink.", "Medium"


def generate_rows(n_rows):
    rows = []
    # distribution: 5% cat1, 25% cat2, 50% cat3, 20% cat4
    n1 = max(1, int(n_rows * 0.05))
    n2 = max(1, int(n_rows * 0.25))
    n4 = max(1, int(n_rows * 0.20))
    n3 = n_rows - (n1 + n2 + n4)

    # Category 1 (safe after treatment)
    for i in range(n1):
        pH = 6.6 + (i / max(1, n1 - 1)) * (8.4 - 6.6)
        tds = 50 + (i / max(1, n1 - 1)) * (600 - 50)
        turb = 0.2 + (i / max(1, n1 - 1)) * (5.0 - 0.2)
        temp = 15 + (i / max(1, n1 - 1)) * (32 - 15)
        rows.append((pH, tds, turb, temp))

    # Category 2 (washing)
    for i in range(n2):
        pH = 6.0 + (i / max(1, n2 - 1)) * (9.0 - 6.0)
        tds = 100 + (i / max(1, n2 - 1)) * (2000 - 100)
        turb = 1.0 + (i / max(1, n2 - 1)) * (30.0 - 1.0)
        temp = 10 + (i / max(1, n2 - 1)) * (40 - 10)
        rows.append((pH, tds, turb, temp))

    # Category 3 (marginal)
    for i in range(n3):
        pH = 6.0 + (i / max(1, n3 - 1)) * (9.5 - 6.0)
        tds = 500 + (i / max(1, n3 - 1)) * (2500 - 500)
        turb = 5.0 + (i / max(1, n3 - 1)) * (60.0 - 5.0)
        temp = 20 + (i / max(1, n3 - 1)) * (38 - 20)
        rows.append((pH, tds, turb, temp))

    # Category 4 (too dirty)
    for i in range(n4):
        if i % 2 == 0:
            pH = 5.0 + (i / max(1, n4 - 1)) * (5.9 - 5.0)  # acidic
        else:
            pH = 9.1 + (i / max(1, n4 - 1)) * (11.0 - 9.1)  # alkaline
        tds = 3001 + (i / max(1, n4 - 1)) * (5000 - 3001)
        turb = 51.0 + (i / max(1, n4 - 1)) * (200.0 - 51.0)
        temp = 41.0 + (i / max(1, n4 - 1)) * (60.0 - 41.0)
        rows.append((pH, tds, turb, temp))

    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rows', type=int, default=500)
    parser.add_argument('--out', type=str, default='water_quality_training_data.csv')
    args = parser.parse_args()

    rows = generate_rows(args.rows)

    with open(args.out, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['pH','TDS','Turbidity','Temperature','pH_score','TDS_score','Turbidity_score','Temp_score','WQI','Category','Recommended_Use','Safety_Advice','Risk_Level'])
        for (pH, tds, turb, temp) in rows:
            qph = score_pH(pH)
            qtds = score_TDS(tds)
            qturb = score_Turbidity(turb)
            qtemp = score_Temperature(temp)
            wqi = qph * WQI_WEIGHT_PH + qtds * WQI_WEIGHT_TDS + qturb * WQI_WEIGHT_TURBIDITY + qtemp * WQI_WEIGHT_TEMPERATURE
            cat_num, cat_label, advice, risk = label_from_values(pH, tds, turb, temp)
            # Recommended_Use text
            if cat_num == 1:
                use = 'Drink after treatment + washing'
            elif cat_num == 2:
                use = 'Washing clothes/dishes/bathing'
            elif cat_num == 3:
                use = 'Marginal / limited use'
            else:
                use = 'Too dirty - not recommended'

            writer.writerow([f"{pH:.2f}", f"{tds:.1f}", f"{turb:.2f}", f"{temp:.1f}", f"{qph:.1f}", f"{qtds:.1f}", f"{qturb:.1f}", f"{qtemp:.1f}", f"{wqi:.1f}", cat_num, use, advice, risk])

    print(f"Generated {args.rows} rows -> {args.out}")

if __name__ == '__main__':
    main()
