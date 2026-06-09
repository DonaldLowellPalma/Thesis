Synthetic Water Quality Dataset Generator

Files:

- `generate_synthetic_dataset.py` - Python script to generate synthetic training data.
- `data/water_quality_training_data_sample.csv` - 20-row sample CSV included for quick preview.

Usage:

1. Create a Python environment (recommended):

```bash
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

pip install --upgrade pip
pip install numpy pandas
```

2. Generate 500 rows (default rows=500):

```bash
python generate_synthetic_dataset.py --rows 500 --out water_quality_training_data.csv
```

3. The output CSV contains columns:
   `pH,TDS,Turbidity,Temperature,pH_score,TDS_score,Turbidity_score,Temp_score,WQI,Category,Recommended_Use,Safety_Advice,Risk_Level`

Notes:

- This synthetic dataset is conservative and safety-focused, intended for initial model experiments and testing only.
- For production-grade models, collect real labeled samples and consider adding features (e.g., seasonal, rainfall) and real-world noise.
- The category mapping: 1=Drink_after_treatment, 2=Washing_safe, 3=Marginal, 4=Too_dirty

License: Use for development and research. Not a medical device.
