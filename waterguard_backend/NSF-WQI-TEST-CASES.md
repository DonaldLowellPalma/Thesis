# NSF-WQI Implementation Test Cases

## Test Case 1: Excellent Water Quality
**Input:**
- Turbidity: 2 NTU (very clear)
- pH: 7.2 (optimal range)
- Temperature: 23°C (optimal range)
- TDS: 200 ppm (clean water)

**Expected Q-Values:**
- Q_Turbidity = 100 - (2/5)*10 = 96
- Q_pH = 100 - |7.2-7.0|*10 = 98
- Q_Temperature = 100 - |23-22.5|*2 = 99
- Q_TDS = 100 - (200/100)*5 = 90

**Expected WQI:**
- WQI = 0.25*96 + 0.25*98 + 0.15*99 + 0.35*90 = 24 + 24.5 + 14.85 + 31.5 = **94.85**
- Category: **Excellent** (Green #6BCB77)

---

## Test Case 2: Good Water Quality
**Input:**
- Turbidity: 15 NTU
- pH: 7.5 (slightly alkaline but acceptable)
- Temperature: 25°C (slightly warm)
- TDS: 600 ppm

**Expected Q-Values:**
- Q_Turbidity = 80 - ((15-10)/40)*40 = 80 - 5 = 75
- Q_pH = 100 - |7.5-7.0|*10 = 95
- Q_Temperature = 100 - |25-22.5|*2 = 95
- Q_TDS = 95 - ((600-100)/400)*25 = 95 - 31.25 = 63.75

**Expected WQI:**
- WQI = 0.25*75 + 0.25*95 + 0.15*95 + 0.35*63.75 = 18.75 + 23.75 + 14.25 + 22.3 = **79.05**
- Category: **Good** (Light Green #9CCC65)

---

## Test Case 3: Fair Water Quality
**Input:**
- Turbidity: 50 NTU (noticeably cloudy)
- pH: 6.0 (slightly acidic)
- Temperature: 18°C (cooler)
- TDS: 1200 ppm (very high)

**Expected Q-Values:**
- Q_Turbidity = 40 - ((50-50)/50)*20 = 40
- Q_pH = 80 - ((6.5-6.0)/0.5)*20 = 80 - 20 = 60
- Q_Temperature = 100 - ((20-18)/5)*20 = 100 - 8 = 92
- Q_TDS = 40 - ((1200-1000)/500)*20 = 40 - 8 = 32

**Expected WQI:**
- WQI = 0.25*40 + 0.25*60 + 0.15*92 + 0.35*32 = 10 + 15 + 13.8 + 11.2 = **50**
- Category: **Fair** (Yellow #FFD93D)

---

## Test Case 4: Poor Water Quality
**Input:**
- Turbidity: 200 NTU (very turbid)
- pH: 5.0 (moderately acidic)
- Temperature: 32°C (very warm)
- TDS: 1800 ppm (very high)

**Expected Q-Values:**
- Q_Turbidity = 20 - ((200-100)/100)*15 = 20 - 15 = 5
- Q_pH = 60 - ((6.0-5.0)/1.0)*30 = 60 - 30 = 30
- Q_Temperature = 80 - ((32-30)/5)*30 = 80 - 12 = 68
- Q_TDS = 20 - ((1800-1500)/500)*20 = 20 - 12 = 8

**Expected WQI:**
- WQI = 0.25*5 + 0.25*30 + 0.15*68 + 0.35*8 = 1.25 + 7.5 + 10.2 + 2.8 = **21.75**
- Category: **Very Poor** (Red #FF6B6B)

---

## Test Case 5: Boundary Test - Score 89.9 (Should be "Good")
**Input:**
- Turbidity: 5 NTU
- pH: 7.0
- Temperature: 22°C
- TDS: 400 ppm

**Expected Q-Values:**
- Q_Turbidity = 100 - (5/5)*10 = 90
- Q_pH = 100
- Q_Temperature = 100 - |22-22.5|*2 = 99
- Q_TDS = 95 - ((400-100)/400)*25 = 95 - 18.75 = 76.25

**Expected WQI:**
- WQI = 0.25*90 + 0.25*100 + 0.15*99 + 0.35*76.25 = 22.5 + 25 + 14.85 + 26.69 = **89.04**
- Category: **Good** (Light Green #9CCC65)

---

## Test Case 6: Boundary Test - Score 90.0 (Should be "Excellent")
**Input:**
- Turbidity: 3 NTU
- pH: 7.2
- Temperature: 24°C
- TDS: 350 ppm

**Expected Q-Values:**
- Q_Turbidity = 100 - (3/5)*10 = 94
- Q_pH = 100 - |7.2-7.0|*10 = 98
- Q_Temperature = 100 - |24-22.5|*2 = 97
- Q_TDS = 100 - (350/100)*5 = 82.5

**Expected WQI:**
- WQI = 0.25*94 + 0.25*98 + 0.15*97 + 0.35*82.5 = 23.5 + 24.5 + 14.55 + 28.875 = **91.425**
- Category: **Excellent** (Green #6BCB77)

---

## Backend Test Script

To test the NSF-WQI calculations, run this code in Node.js:

```javascript
const { calculateNSFWQI, getWQICategory } = require('./src/utils');

// Test Case 1
const wqi1 = calculateNSFWQI(2, 7.2, 23, 200);
console.log('Test 1: WQI =', wqi1, 'Expected: ~94.85');
console.log('Category:', getWQICategory(wqi1));

// Test Case 2
const wqi2 = calculateNSFWQI(15, 7.5, 25, 600);
console.log('\nTest 2: WQI =', wqi2, 'Expected: ~79.05');
console.log('Category:', getWQICategory(wqi2));

// Test Case 3
const wqi3 = calculateNSFWQI(50, 6.0, 18, 1200);
console.log('\nTest 3: WQI =', wqi3, 'Expected: ~50');
console.log('Category:', getWQICategory(wqi3));

// Test Case 4
const wqi4 = calculateNSFWQI(200, 5.0, 32, 1800);
console.log('\nTest 4: WQI =', wqi4, 'Expected: ~21.75');
console.log('Category:', getWQICategory(wqi4));

// Test Case 5
const wqi5 = calculateNSFWQI(5, 7.0, 22, 400);
console.log('\nTest 5: WQI =', wqi5, 'Expected: ~89.04');
console.log('Category:', getWQICategory(wqi5));

// Test Case 6
const wqi6 = calculateNSFWQI(3, 7.2, 24, 350);
console.log('\nTest 6: WQI =', wqi6, 'Expected: ~91.425');
console.log('Category:', getWQICategory(wqi6));
```

## Frontend Test Checklist

### Dashboard Tests
- [ ] WQI card displays below Water Quality Overview section
- [ ] WQI score loads and displays within 3 seconds
- [ ] Color background matches category (Green/Yellow/Red/Orange)
- [ ] Sensor readings in breakdown match current live values
- [ ] WQI auto-refreshes every 10 seconds
- [ ] Loading spinner shows briefly during fetch
- [ ] Network error handled gracefully with message

### Sensor Detail Tests
- [ ] WQI breakdown card displays below prediction card
- [ ] WQI score and category badge both visible
- [ ] Sensor contribution weights correctly labeled (25%, 25%, 15%, 35%)
- [ ] Sensor values match those shown on dashboard
- [ ] Card color background matches WQI category
- [ ] Handles missing WQI data without crash

### Color Verification Tests
- [ ] Score 95 → Green (#6BCB77)
- [ ] Score 75 → Light Green (#9CCC65)
- [ ] Score 55 → Yellow (#FFD93D)
- [ ] Score 35 → Orange (#FF9D5C)
- [ ] Score 15 → Red (#FF6B6B)

## API Endpoint Test

```bash
# Get WQI data
curl -X GET http://192.168.126.246:4000/api/sensors/quality-index \
  -H "Authorization: Bearer YOUR_TOKEN"

# Expected Response:
# {
#   "wqiScore": 75.3,
#   "category": "Good",
#   "color": "#9CCC65",
#   "timestamp": "2024-01-15T10:30:00Z",
#   "sensors": {
#     "turbidity": 12.5,
#     "phLevel": 7.2,
#     "temperature": 24.5,
#     "tds": 450
#   }
# }
```
