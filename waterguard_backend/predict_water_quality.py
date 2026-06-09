#!/usr/bin/env python
"""
Water Quality Prediction Script
Called by Node.js backend to predict water quality using trained ML model
Usage: python predict_water_quality.py '{"turbidity": 2.5, "tds": 600, "ph": 7.2, "temperature": 23}'
"""

import sys
import json
import numpy as np

# Try to import joblib and model files
try:
    import joblib
    MODEL_AVAILABLE = True
except ImportError:
    MODEL_AVAILABLE = False
    print("Warning: joblib not installed. Using fallback rules.", file=sys.stderr)

# ============ Fallback Rule-Based Prediction ============

def predict_with_rules(turbidity, tds, ph, temperature):
    """
    Rule-based water quality prediction (fallback when model unavailable)
    """
    turbidity = float(turbidity)
    tds = float(tds)
    ph = float(ph)
    temperature = float(temperature)
    
    # Check critical conditions (NOT_RECOMMENDED)
    if turbidity > 25 or tds > 1500 or ph < 4.5 or ph > 10.5 or temperature > 45 or temperature < 0:
        return {
            'category': 'NOT_RECOMMENDED',
            'confidence': 0.85,
            'probabilities': {
                'EXCELLENT': 0.05,
                'DRINKABLE_WITH_TREATMENT': 0.05,
                'SAFE_FOR_WASHING': 0.05,
                'NOT_RECOMMENDED': 0.85
            }
        }
    
    # Check for excellent water
    if turbidity < 1 and tds < 500 and 6.5 <= ph <= 8.5 and 15 <= temperature <= 25:
        return {
            'category': 'EXCELLENT',
            'confidence': 0.90,
            'probabilities': {
                'EXCELLENT': 0.90,
                'DRINKABLE_WITH_TREATMENT': 0.07,
                'SAFE_FOR_WASHING': 0.02,
                'NOT_RECOMMENDED': 0.01
            }
        }
    
    # Check for drinkable with treatment
    if turbidity < 3 and tds < 800 and 6.0 <= ph <= 8.5 and 5 <= temperature <= 35:
        return {
            'category': 'DRINKABLE_WITH_TREATMENT',
            'confidence': 0.80,
            'probabilities': {
                'EXCELLENT': 0.15,
                'DRINKABLE_WITH_TREATMENT': 0.70,
                'SAFE_FOR_WASHING': 0.12,
                'NOT_RECOMMENDED': 0.03
            }
        }
    
    # Default: safe for washing
    return {
        'category': 'SAFE_FOR_WASHING',
        'confidence': 0.75,
        'probabilities': {
            'EXCELLENT': 0.05,
            'DRINKABLE_WITH_TREATMENT': 0.15,
            'SAFE_FOR_WASHING': 0.75,
            'NOT_RECOMMENDED': 0.05
        }
    }

# ============ ML Model Prediction ============

def predict_with_model(turbidity, tds, ph, temperature):
    """
    ML-based water quality prediction using trained Gradient Boosting model
    """
    if not MODEL_AVAILABLE:
        return predict_with_rules(turbidity, tds, ph, temperature)
    
    try:
        # Load model and scaler
        model = joblib.load('water_quality_model.pkl')
        scaler = joblib.load('water_quality_scaler.pkl')
        
        # Scale features
        X = np.array([[turbidity, tds, ph, temperature]])
        X_scaled = scaler.transform(X)
        
        # Predict
        prediction = model.predict(X_scaled)[0]
        probabilities = model.predict_proba(X_scaled)[0]
        confidence = float(max(probabilities))

        # Map to categories (supports numeric labels 0..3 or string labels)
        label_map = {
            0: 'EXCELLENT',
            1: 'DRINKABLE_WITH_TREATMENT',
            2: 'SAFE_FOR_WASHING',
            3: 'NOT_RECOMMENDED'
        }

        if isinstance(prediction, (np.integer, int)):
            category = label_map.get(int(prediction), 'SAFE_FOR_WASHING')
        else:
            category = str(prediction)

        # Build probability map from model.classes_ so order stays correct
        classes = getattr(model, 'classes_', [0, 1, 2, 3])
        probability_map = {}
        for cls, prob in zip(classes, probabilities):
            if isinstance(cls, (np.integer, int)):
                cls_name = label_map.get(int(cls), str(int(cls)))
            else:
                cls_name = str(cls)
            probability_map[cls_name] = float(prob)

        return {
            'category': category,
            'confidence': confidence,
            'probabilities': probability_map
        }
    
    except (FileNotFoundError, Exception) as e:
        print(f"Model loading error: {e}. Using fallback rules.", file=sys.stderr)
        return predict_with_rules(turbidity, tds, ph, temperature)

# ============ Main Execution ============

if __name__ == '__main__':
    try:
        # Get input from command line
        if len(sys.argv) < 2:
            print(json.dumps({
                'error': 'Missing input',
                'usage': 'python predict_water_quality.py \'{"turbidity": X, "tds": X, "ph": X, "temperature": X}\''
            }))
            sys.exit(1)
        
        # Parse JSON input
        input_data = json.loads(sys.argv[1])
        
        turbidity = input_data.get('turbidity')
        tds = input_data.get('tds')
        ph = input_data.get('ph')
        temperature = input_data.get('temperature')
        
        # Validate
        if turbidity is None or tds is None or ph is None or temperature is None:
            print(json.dumps({
                'error': 'Missing required fields',
                'required': ['turbidity', 'tds', 'ph', 'temperature']
            }))
            sys.exit(1)
        
        # Get prediction
        result = predict_with_model(turbidity, tds, ph, temperature)
        
        # Output as JSON
        print(json.dumps(result))
    
    except json.JSONDecodeError as e:
        print(json.dumps({
            'error': f'Invalid JSON input: {str(e)}'
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({
            'error': str(e)
        }))
        sys.exit(1)
