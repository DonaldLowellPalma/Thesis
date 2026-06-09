#!/usr/bin/env python3
"""
Simple training script to create a RandomForest classifier from sample CSV data.
Produces src/ml/model.pkl when run. Requires scikit-learn and pandas.
"""
import os
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib


def main():
    base = os.path.dirname(__file__)
    data_path = os.path.join(base, "sample_data.csv")
    if not os.path.exists(data_path):
        print("sample_data.csv not found in src/ml/")
        return

    df = pd.read_csv(data_path)
    # Expect columns: turbidity,tds,ph,temperature,label
    X = df[["turbidity", "tds", "ph", "temperature"]].fillna(0)
    y = df["label"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    clf = RandomForestClassifier(n_estimators=100, random_state=42)
    clf.fit(X_train, y_train)
    score = clf.score(X_test, y_test)
    model_path = os.path.join(base, "model.pkl")
    joblib.dump(clf, model_path)
    print(f"Trained RandomForest saved to {model_path}, test accuracy={score:.3f}")


if __name__ == "__main__":
    main()
