# ML model (Random Forest) helper

This folder contains a small example training script and a predictor used by the Node backend.

Commands:

- Create a Python virtualenv, install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

- Train a model from the provided sample data:

```bash
python train.py
# This writes model.pkl into this folder
```

- Test a prediction from the command line (JSON via stdin):

```bash
echo '{"turbidity": 20, "tds": 500, "phLevel": 7.0, "temperature": 22}' | python predict.py
```

Notes:

- The Node route `/api/predict` will call `python src/ml/predict.py` and parse its JSON output.
- If `model.pkl` is not present or Python is unavailable, the predictor returns a small rule-based fallback.

## Colab training quick-start

1. Open a new Google Colab notebook.

2. In the first cell, install dependencies and upload the sample data (or mount Drive):

```python
!pip install scikit-learn pandas joblib
from google.colab import files
# Upload sample_data.csv from your machine or skip to mount Drive
uploaded = files.upload()
```

3. Training cell (copy into a new cell):

```python
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib

df = pd.read_csv('sample_data.csv')
X = df[['turbidity','tds','ph','temperature']]
 y = df['label']
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)
print('Test acc:', clf.score(X_test, y_test))
joblib.dump(clf, 'model.pkl')
files.download('model.pkl')
```

4. Download `model.pkl` and place it into `src/ml/model.pkl` in the backend repository, then restart your Node backend.

Security note: do not commit model.pkl with secrets or private data to a public repo.
