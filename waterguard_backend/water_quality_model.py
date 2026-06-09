"""
WaterGuard Water Quality Assessment Model
Comprehensive ML-based water quality determination system
Uses sensor data to predict water quality categories

Categories:
- NOT_RECOMMENDED: Water unsafe for any use
- SAFE_FOR_WASHING: Safe for bathing, washing clothes/dishes
- DRINKABLE_WITH_TREATMENT: Safe to drink after proper filtration + disinfection
- EXCELLENT: Safe for direct drinking (rare)
"""

import json
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import joblib
import warnings
warnings.filterwarnings('ignore')

# ============ Water Quality Standards & Thresholds ============

WATER_QUALITY_STANDARDS = {
    'turbidity_ntu': {
        'excellent': {'max': 0.5, 'description': 'Crystal clear, excellent clarity'},
        'good': {'max': 1.0, 'description': 'Clear, minimal particles'},
        'fair': {'max': 5.0, 'description': 'Slightly cloudy, acceptable'},
        'poor': {'max': 25.0, 'description': 'Noticeable cloudiness'},
        'very_poor': {'max': 100.0, 'description': 'Very turbid, murky'},
        'critical': {'max': float('inf'), 'description': 'Extremely turbid'}
    },
    
    'tds_ppm': {
        'excellent': {'max': 50, 'description': 'Distilled/RO quality'},
        'good': {'max': 150, 'description': 'Fresh water, ideal for drinking'},
        'fair': {'max': 500, 'description': 'Acceptable for drinking'},
        'poor': {'max': 1000, 'description': 'High mineral content'},
        'very_poor': {'max': 1500, 'description': 'Very high salinity'},
        'critical': {'max': float('inf'), 'description': 'Unusable salinity'}
    },
    
    'ph': {
        'excellent': {'min': 7.0, 'max': 7.5, 'description': 'Neutral, balanced'},
        'good': {'min': 6.5, 'max': 8.0, 'description': 'Acceptable range'},
        'fair': {'min': 6.0, 'max': 8.5, 'description': 'Slightly out of balance'},
        'poor': {'min': 5.5, 'max': 9.0, 'description': 'Notable acidity/alkalinity'},
        'very_poor': {'min': 4.5, 'max': 9.5, 'description': 'High acidity/alkalinity'},
        'critical': {'min': 0.0, 'max': 14.0, 'description': 'Caustic or corrosive'}
    },
    
    'temperature_celsius': {
        'excellent': {'min': 15, 'max': 25, 'description': 'Optimal temperature'},
        'good': {'min': 10, 'max': 30, 'description': 'Acceptable range'},
        'fair': {'min': 5, 'max': 35, 'description': 'Outside optimal but usable'},
        'poor': {'min': 0, 'max': 40, 'description': 'Extreme temperature'},
        'critical': {'min': -273.15, 'max': float('inf'), 'description': 'Unusable'}
    }
}

QUALITY_CATEGORIES = {
    'EXCELLENT': {
        'score': 90,
        'description': 'Safe for direct drinking - excellent quality',
        'icon': '✓✓✓',
        'color': 'green'
    },
    'DRINKABLE_WITH_TREATMENT': {
        'score': 70,
        'description': 'Safe to drink AFTER proper filtration + disinfection',
        'icon': '✓✓',
        'color': 'yellow'
    },
    'SAFE_FOR_WASHING': {
        'score': 50,
        'description': 'Safe for washing clothes / dishes / bathing',
        'icon': '✓',
        'color': 'orange'
    },
    'NOT_RECOMMENDED': {
        'score': 0,
        'description': 'Too dirty / Not recommended for any use',
        'icon': '✗',
        'color': 'red'
    }
}

# ============ Synthetic Training Data Generation ============

def generate_training_data(n_samples=500):
    """
    Generate synthetic water quality training data with realistic distributions
    Returns DataFrame with features and labels
    """
    np.random.seed(42)
    
    data = []
    
    # EXCELLENT quality samples (rare - 5%)
    for _ in range(int(n_samples * 0.05)):
        turbidity = np.random.normal(0.3, 0.15)
        tds = np.random.normal(100, 30)
        ph = np.random.normal(7.0, 0.2)
        temperature = np.random.normal(20, 3)
        data.append({
            'turbidity': max(0, turbidity),
            'tds': max(0, tds),
            'ph': np.clip(ph, 0, 14),
            'temperature': max(-10, temperature),
            'quality': 'EXCELLENT'
        })
    
    # DRINKABLE_WITH_TREATMENT samples (25%)
    for _ in range(int(n_samples * 0.25)):
        turbidity = np.random.normal(0.7, 0.4)
        tds = np.random.normal(300, 100)
        ph = np.random.normal(7.0, 0.4)
        temperature = np.random.normal(22, 4)
        data.append({
            'turbidity': np.clip(turbidity, 0, 3),
            'tds': np.clip(tds, 50, 800),
            'ph': np.clip(ph, 6.0, 8.0),
            'temperature': np.clip(temperature, 5, 35),
            'quality': 'DRINKABLE_WITH_TREATMENT'
        })
    
    # SAFE_FOR_WASHING samples (50%)
    for _ in range(int(n_samples * 0.50)):
        turbidity = np.random.normal(2.5, 1.5)
        tds = np.random.normal(700, 250)
        ph = np.random.normal(7.2, 0.8)
        temperature = np.random.normal(23, 5)
        data.append({
            'turbidity': np.clip(turbidity, 0, 10),
            'tds': np.clip(tds, 200, 1400),
            'ph': np.clip(ph, 5.5, 8.5),
            'temperature': np.clip(temperature, 0, 40),
            'quality': 'SAFE_FOR_WASHING'
        })
    
    # NOT_RECOMMENDED samples (20%)
    for _ in range(int(n_samples * 0.20)):
        choice = np.random.choice([0, 1, 2])
        if choice == 0:  # Too turbid
            turbidity = np.random.uniform(15, 100)
            tds = np.random.normal(500, 200)
            ph = np.random.normal(7.0, 0.5)
        elif choice == 1:  # Too much dissolved solids
            turbidity = np.random.normal(2, 1)
            tds = np.random.uniform(1600, 3000)
            ph = np.random.normal(7.0, 0.5)
        else:  # Extreme pH
            turbidity = np.random.normal(2, 1)
            tds = np.random.normal(700, 200)
            ph = np.random.choice([
                np.random.uniform(0, 4),  # Very acidic
                np.random.uniform(10, 14)  # Very alkaline
            ])
        
        temperature = np.random.normal(23, 5)
        data.append({
            'turbidity': max(0, turbidity),
            'tds': max(0, tds),
            'ph': np.clip(ph, 0, 14),
            'temperature': np.clip(temperature, -10, 50),
            'quality': 'NOT_RECOMMENDED'
        })
    
    return pd.DataFrame(data)

# ============ Model Training ============

class WaterQualityModel:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = ['turbidity', 'tds', 'ph', 'temperature']
        self.quality_categories = list(QUALITY_CATEGORIES.keys())
        
    def train(self, df_training_data):
        """Train the water quality classification model"""
        X = df_training_data[self.feature_names].values
        y = df_training_data['quality'].values
        
        # Standardize features
        X_scaled = self.scaler.fit_transform(X)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X_scaled, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train ensemble model
        self.model = GradientBoostingClassifier(
            n_estimators=100,
            learning_rate=0.1,
            max_depth=5,
            random_state=42,
            verbose=0
        )
        
        self.model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = self.model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        print("=" * 60)
        print("WATER QUALITY MODEL TRAINING RESULTS")
        print("=" * 60)
        print(f"Model Accuracy: {accuracy:.2%}")
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred))
        print("\nConfusion Matrix:")
        print(confusion_matrix(y_test, y_pred))
        print("=" * 60)
        
        return {
            'accuracy': accuracy,
            'model': self.model,
            'y_test': y_test,
            'y_pred': y_pred
        }
    
    def predict(self, turbidity, tds, ph, temperature):
        """
        Predict water quality category
        Args:
            turbidity: NTU (0-3000)
            tds: ppm (0-2000)
            ph: pH units (0-14)
            temperature: Celsius (-10 to 50)
        Returns:
            prediction dict with category, confidence, and recommendations
        """
        if self.model is None:
            raise ValueError("Model not trained. Call train() first.")
        
        # Validate inputs
        turbidity = np.clip(float(turbidity), 0, 3000)
        tds = np.clip(float(tds), 0, 2000)
        ph = np.clip(float(ph), 0, 14)
        temperature = np.clip(float(temperature), -10, 50)
        
        # Scale features
        X = np.array([[turbidity, tds, ph, temperature]])
        X_scaled = self.scaler.transform(X)
        
        # Predict
        prediction = self.model.predict(X_scaled)[0]
        probabilities = self.model.predict_proba(X_scaled)[0]
        confidence = float(max(probabilities))
        
        # Build response
        result = {
            'category': prediction,
            'confidence': confidence,
            'score': QUALITY_CATEGORIES[prediction]['score'],
            'description': QUALITY_CATEGORIES[prediction]['description'],
            'icon': QUALITY_CATEGORIES[prediction]['icon'],
            'color': QUALITY_CATEGORIES[prediction]['color'],
            'sensor_data': {
                'turbidity_ntu': round(turbidity, 2),
                'tds_ppm': round(tds, 2),
                'ph': round(ph, 2),
                'temperature_celsius': round(temperature, 2)
            },
            'probabilities': {
                cat: float(prob) 
                for cat, prob in zip(self.quality_categories, probabilities)
            },
            'recommendations': self._get_recommendations(prediction, turbidity, tds, ph)
        }
        
        return result
    
    def _get_recommendations(self, category, turbidity, tds, ph):
        """Generate water usage recommendations"""
        recommendations = []
        
        if category == 'EXCELLENT':
            recommendations = [
                '✓ Safe for direct drinking',
                '✓ Safe for cooking',
                '✓ Safe for bathing',
                '✓ Safe for all household uses',
                'No treatment needed'
            ]
        elif category == 'DRINKABLE_WITH_TREATMENT':
            recommendations = [
                '⚠ Safe to drink ONLY after:',
                '  - Boiling for 1+ minute, OR',
                '  - Using certified water filter (0.5-1 micron), OR',
                '  - UV disinfection + filtration',
                '✓ Safe for bathing/washing',
                '✓ Safe for cooking (after treatment)'
            ]
        elif category == 'SAFE_FOR_WASHING':
            recommendations = [
                '✓ Safe for bathing',
                '✓ Safe for washing clothes/dishes',
                '✓ Safe for irrigation',
                '✗ NOT safe for drinking',
                '⚠ May cause skin irritation with prolonged contact'
            ]
        else:  # NOT_RECOMMENDED
            recommendations = [
                '✗ NOT safe for drinking',
                '✗ NOT safe for bathing',
                '✗ Use only for minimal irrigation',
                '⚠ Risk of staining clothes, damaging pipes'
            ]
            
            # Add specific warnings
            if turbidity > 25:
                recommendations.append('⚠ Excessive turbidity - needs filtration')
            if tds > 1500:
                recommendations.append('⚠ Excessive dissolved solids - high salinity')
            if ph < 4.5 or ph > 10:
                recommendations.append('⚠ Extreme pH - caustic or corrosive')
        
        return recommendations
    
    def save_model(self, model_path='water_quality_model.pkl', 
                   scaler_path='water_quality_scaler.pkl'):
        """Save trained model and scaler"""
        joblib.dump(self.model, model_path)
        joblib.dump(self.scaler, scaler_path)
        print(f"Model saved to {model_path}")
        print(f"Scaler saved to {scaler_path}")
    
    def load_model(self, model_path='water_quality_model.pkl',
                   scaler_path='water_quality_scaler.pkl'):
        """Load trained model and scaler"""
        self.model = joblib.load(model_path)
        self.scaler = joblib.load(scaler_path)
        print(f"Model loaded from {model_path}")
        print(f"Scaler loaded from {scaler_path}")


# ============ Main Training Script ============

if __name__ == '__main__':
    print("WaterGuard Water Quality Model Training")
    print("=" * 60)
    
    # Generate training data
    print("\nGenerating synthetic training data...")
    df = generate_training_data(n_samples=500)
    print(f"Generated {len(df)} samples")
    print(f"\nData distribution:\n{df['quality'].value_counts()}")
    
    # Train model
    print("\nTraining Water Quality Model...")
    wq_model = WaterQualityModel()
    results = wq_model.train(df)
    
    # Test predictions
    print("\n" + "=" * 60)
    print("SAMPLE PREDICTIONS")
    print("=" * 60)
    
    test_cases = [
        {'turbidity': 0.3, 'tds': 80, 'ph': 7.1, 'temperature': 20, 'label': 'EXCELLENT Water'},
        {'turbidity': 0.8, 'tds': 250, 'ph': 7.0, 'temperature': 22, 'label': 'DRINKABLE Water'},
        {'turbidity': 3.0, 'tds': 600, 'ph': 7.2, 'temperature': 24, 'label': 'WASHING Water'},
        {'turbidity': 50.0, 'tds': 2000, 'ph': 3.5, 'temperature': 25, 'label': 'NOT RECOMMENDED Water'},
    ]
    
    for test in test_cases:
        print(f"\n{test['label']}")
        print(f"  Turbidity: {test['turbidity']} NTU")
        print(f"  TDS: {test['tds']} ppm")
        print(f"  pH: {test['ph']}")
        print(f"  Temperature: {test['temperature']}°C")
        
        pred = wq_model.predict(
            test['turbidity'],
            test['tds'],
            test['ph'],
            test['temperature']
        )
        
        print(f"\n  ➜ Category: {pred['category']} (confidence: {pred['confidence']:.1%})")
        print(f"  ➜ {pred['description']}")
        print(f"  ➜ Recommendations:")
        for rec in pred['recommendations']:
            print(f"     {rec}")
    
    # Save model
    print("\n" + "=" * 60)
    wq_model.save_model()
    print("Training complete!")
