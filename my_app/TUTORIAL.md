# WATERGUARD App Tutorial

Welcome to **WATERGUARD** - Your Water Quality Monitoring Companion! This tutorial will guide you through all the features of the app.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Account Setup](#account-setup)
3. [Dashboard Overview](#dashboard-overview)
4. [Monitoring Sensors](#monitoring-sensors)
5. [Viewing History](#viewing-history)
6. [Notifications](#notifications)
7. [Managing Your Profile](#managing-your-profile)
8. [Understanding Water Quality Metrics](#understanding-water-quality-metrics)

---

## Getting Started

### First Launch

When you open WATERGUARD for the first time, you'll see a welcome screen. The app will automatically load your session if you've previously logged in. Otherwise, you'll be directed to sign up or log in.

### Requirements

- Internet connection (required for real-time sensor data)
- Valid email address
- Password (minimum security requirements apply)

---

## Account Setup

### Sign Up (New Users) - Detailed Steps

1. **Open the WATERGUARD app** on your mobile device
2. **On the Welcome Screen, tap the "Sign Up" button** (white button with black text)
3. **You'll see the Sign Up page with three input fields**
4. **In the first field labeled "Name":**
   - Tap the text field
   - Enter your full name (e.g., "John Doe")
   - Move to the next field
5. **In the second field labeled "Email":**
   - Tap the text field
   - Enter a valid email address (e.g., "john.doe@example.com")
   - This will be used to log in, so remember it
   - Move to the next field
6. **In the third field labeled "Password":**
   - Tap the text field
   - Enter a strong password (at least 8 characters recommended)
   - Include uppercase, lowercase, and numbers for security
   - Move to the next field
7. **In the fourth field labeled "Confirm Password":**
   - Re-enter the exact same password
   - Make sure it matches perfectly
8. **Review your information** for any typos
9. **Tap the "Sign Up" button** (blue button at the bottom)
10. **Wait for processing** (you'll see a loading spinner)
11. **If successful:**
    - You'll see a "Sign up successful!" message
    - The app automatically logs you in
    - You'll be taken to the Dashboard
12. **If there's an error:**
    - Check that email isn't already registered
    - Ensure password meets requirements
    - Try again with correct information

### Log In (Existing Users) - Detailed Steps

1. **Open the WATERGUARD app**
2. **On the Welcome Screen, tap the "Login" button** (white button)
3. **You'll see the Login page with two input fields**
4. **In the first field labeled "Email":**
   - Tap the email text field
   - Enter the email you signed up with
   - Example: "john.doe@example.com"
5. **In the second field labeled "Password":**
   - Tap the password text field
   - Enter your password
   - The text will be hidden with dots for security
6. **If you forgot your password:**
   - Look for "Forgot Password?" link below the fields
   - Tap it
   - Enter your email
   - You'll receive a password reset link via email
   - Follow the instructions to create a new password
   - Return to login with your new password
7. **Tap the blue "Login" button**
8. **Wait for authentication** (loading spinner appears)
9. **If login is successful:**
   - You'll briefly see the Splash Screen
   - Then you'll be taken to the Dashboard
10. **If login fails:**
    - Check email and password for typos
    - Ensure CAPS LOCK is off
    - Try "Forgot Password?" if you don't remember your password
    - Contact support if issues persist

---

## Dashboard Overview

The **Dashboard** is your main hub for monitoring water quality. Here's what you see and how to use it:

### Bottom Navigation Menu - Step by Step

At the very bottom of your screen, you'll see 4 icon buttons. These are your main navigation buttons:

1. **📊 Dashboard Tab** (leftmost icon)
   - Current location when you first log in
   - Shows all real-time sensor data
   - Main overview of water quality

2. **📈 History Tab** (second from left)
   - Tap this to see past sensor readings
   - View trends and historical data

3. **🔔 Notifications Tab** (second from right)
   - Tap this to see alerts and messages
   - Shows when sensors are out of range

4. **👤 Profile Tab** (rightmost icon)
   - Tap this to manage your account
   - Change settings and preferences

### Understanding the Dashboard Display

**At the top:**

- App title "WATERGUARD"
- Current location/device name (if multiple sensors)

**In the middle - Sensor Cards:**
Each sensor appears as a card showing:

- **Sensor Icon** (on the left) - Visual symbol for the sensor type
- **Sensor Name** (top) - Name of what's being measured
- **Current Value** (large, bold) - The current reading
- **Unit** (next to value) - Measurement unit (NTU, °C, pH, etc.)
- **Trend Arrow** (top right):
  - ↑ means value is increasing
  - ↓ means value is decreasing
  - ↔️ means value is stable
- **Status Color:**
  - 🟢 Green = Within safe range (good)
  - 🟡 Yellow = Approaching limits (caution)
  - 🔴 Red = Outside safe range (danger)

**Water Quality Index (WQI) Card:**

- Shows a score from 0-100
- Displays overall water quality rating:
  - "Good", "Fair", "Poor", etc.
- Color-coded background

**Scrolling:**

- Scroll down to see all available sensors
- Different water quality locations may have different sensors

### Common Actions on the Dashboard

**To view detailed information about a sensor:**

1. Find the sensor card you want to know more about
2. Tap anywhere on that card
3. You'll see a detailed view with:
   - Full sensor name and description
   - Current reading with unit
   - Safe operating range (min-max values)
   - Color indicator
   - Recent trend graph
   - Min, Max, Average statistics

**To refresh sensor data:**

1. Pull down from the top of the screen (swipe down)
2. You'll see a "refresh" spinner
3. Wait a few seconds
4. Data updates automatically

**To navigate to other sections:**

1. Tap the icon at the bottom for the section you want:
   - History: See past data
   - Notifications: See alerts
   - Profile: Manage account

---

## Monitoring Sensors

### View Real-Time Sensor Data - Step by Step

1. **You're on the Dashboard** (📊 tab is highlighted at the bottom)
2. **Look at all the colored cards** showing different sensors
3. **Each card updates automatically** with new readings from sensors
4. **The sensor values change** as new data arrives from ESP32 sensors
5. **Trend arrows show:**
   - ↑ Rising (value getting higher)
   - ↓ Falling (value getting lower)
   - ↔️ Stable (staying the same)
6. **Color status shows health:**
   - 🟢 Green = Healthy (within safe range)
   - 🟡 Yellow = Caution (approaching limits)
   - 🔴 Red = Danger (outside safe range - action needed)
7. **To see more sensors:**
   - Scroll down on the Dashboard
   - Additional sensor cards will appear

### View Detailed Sensor Information - Step by Step

1. **On the Dashboard, find the sensor you want to examine**
   - Example: Water Clarity, Temperature, pH Level, etc.
2. **Tap on the sensor card** (anywhere on the card)
3. **The Sensor Detail page opens** showing:
   - **Large sensor icon** at the top
   - **Sensor name** - Full name of the measurement
   - **Large current value** in the center
   - **Unit of measurement** below the value
   - **Safe range box:**
     - Shows minimum and maximum safe values
     - Green if current reading is safe
     - Red if current reading is unsafe
4. **Below the current reading, you'll see:**
   - **Status line** - "Status: Safe" or "Status: Unsafe"
   - **Trend line** - "Trend: Increasing/Decreasing/Stable"
   - **Last updated** - When this reading was taken
5. **Further down the page:**
   - **Trend graph** - Visual representation of recent changes
   - **Statistics box:** - Step by Step

6. **On the Dashboard, look at the bottom navigation**
7. **Tap the 📈 History icon** (second from the left)
8. **The History page loads** showing a list of past data
9. **You'll see:**
   - A list of all sensors with their past readings
   - Date and time of each reading
   - Previous values for comparison
10. **To view a specific sensor's history:**
    - Scroll through the list to find the sensor
    - Tap on that sensor
    - See detailed historical data
11. **The graph shows:**
    - Time on the horizontal axis (days/hours)
    - Sensor values on the vertical axis
    - A line connecting all past readings
    - Trends over the selected time period

### Analyzing Trends - Step by Step

1. **On the History page, look at the trend graph**
2. **Observe the line direction:**
   - **Line going UP** = Values are increasing over time
   - **Line going DOWN** = Values are decreasing over time
   - **Line flat** = Values staying consistent
3. **Look for patterns:**
   - Does the value increase at certain times?
   - Does it decrease at other times?
   - Is there a regular daily pattern?
4. **Compare different time periods:**
   - Tap on date filters if available
   - Compare this week vs last week
   - Compare this month vs last month
5. **Identify improvement areas:**
   - Look for Red zones in history
   - Check if those values have improved
   - See if sensor readings are more stable
6. **Use this to predict:**
   - If temperature rises at night, that's normal
   - If pH suddenly drops, sensor may need cleaning
   - If values are trending dangerously, prepare response

### Export Data - Step by Step

1. **On the History page, look for an export button** (usually top right)
2. **Tap the export/download button** (may be three dots ⋯)
3. **Choose your export format:**
   - CSV (spreadsheet format - opens in Excel)
   - PDF (document format - for printing/sharing)
4. **Select date range:**
   - Last 7 days
   - Last 30 days
   - Last 90 days
   - Custom date range
5. **Choose sensors:**
   - All sensors
   - Specific sensors you select
6. **Tap "Export" button**
7. **The file downloads to your device**
8. **You can now:**
   - Share with others
   - Create reports
   - Analyze in Excel
   - Archive for record

- Prepare to take action if it worsens

- 🔴 **RED Box**
  - Sensor value has exceeded safe limits
  - **Action needed immediately**
  - Check the reading, verify it's correct
  - Take corrective measures
  - Contact support if sensor appears faulty

### Sensor Icons Guide - What Each Symbol Means

Each sensor has a unique icon to help you identify it quickly:

- **💧 Water Droplet** = Water Clarity or Turbidity
  - Measures how clear the water is
  - Lower values = clearer water

- **🌡️ Thermometer** = Temperature
  - Measures water temperature in Celsius
  - Different organisms have different optimal temps

- **⚗️ Test Tube** = pH Level
  - Measureand Manage Notifications - Step by Step

1. **On the Dashboard, look at the bottom navigation**
2. **Tap the 🔔 Notifications icon** (second from right)
3. **The Notifications page opens** showing a list of alerts
4. **Each notification shows:**
   - **Sensor icon** - Which sensor triggered the alert
   - **Alert message** - What the problem is
   - **Timestamp** - When the alert was sent
   - **Severity badge** - Color coded (red/yellow/blue)
5. **To read a notification in detail:**
   - Tap on any notification in the list
   - See full details about the alert
   - See recommended actions
6. **To dismiss a notification:**
   - Swipe the notification left
   - Or tap the X/close button on the notification
7. **To see only unread notifications:**
   - Look for a filter option
   - Select "Unread" or "New"
8. **To see all notifications:**
   - Select "All" in the filter
   - Includes read and old notifications

### Understanding Notification Types

**🔴 CRITICAL (Red alerts):**

- Sensor is far outside safe range
- **Immediate action required**
- Example: Dissolved Oxygen dropped below 2 mg/L
- What to do: Check sensor, verify reading, take corrective action

\*\*🟡 WARNING (Yellow al - Step by Step

1. **On any page, look at the bottom navigation**
2. **Tap the 👤 Profile icon** (far right)
3. **Your Profile page opens** showing:
   - Your profile picture (if available)
   - Your display name
   - Your email address
   - Your account information
   - Settings and preferences options

### Update Your Information - Step by Step

1. **On your Profile page, look for an "Edit Profile" button or pencil icon**
2. **Tap "Edit Profile"**
3. **You'll see editable fields:**
   - **Display Name field:**
     - Tap to select
     - Clear the current name
     - Type your new name
   - **Email field:**
     - Usually cannot be changed without verification
   - **Phone field (if available):**
     - Tap and enter your phone number
   - **Location field (if available):**
     - Tap and enter your location
   - **Units preference:**
     - Tap dropdown
     - Choose Metric (°C, mg/L) or Imperial (°F, ppm)
4. **Review all changes** before saving
5. **Tap "Save" or "Update Profile" button**
6. **Wait for confirmation** (loading spinner appears)
7. **See "Profile Updated Successfully" message**
8. **Your changes are saved**

### Change Password - Step by Step

1. **On your Profile page, scroll down**
2. **Look for "Change Password" or "Security Settings"**
3. **Tap "Change Password"**
4. **Enter your current password:**
   - Tap the field
   - Type your current password
   - This verifies it's really you
5. **Enter your new password:**
   - Tap the "New Password" field
   - Type a new, strong password
   - Include uppercase, lowercase, numbers, and symbols
   - At least 8 characters recommended
6. **Confirm the new password:**
   - Tap the "Confirm Password" field
   - Type the same new password again
   - Passwords must match exactly
7. **Review all entries** for accuracy
8. **Tap "Update Password" or "Change Password" button**
9. **Wait for confirmation** (loading spinner)
10. **See "Password Changed Successfully" message**
11. **You're now logged out** (for security)
12. **Log back in** with your new password

### Notification Preferences - Step by Step

1. **On your Profile page, scroll down**
2. **Find and tap "Notification Preferences" or "Notification Settings"**
3. **You'll see sections for different alert types:**
   - **Critical Alerts** (Red)
     - Toggle ON to receive critical alerts
     - Toggle OFF to disable critical alerts
   - **Warning Alerts** (Yellow)
     - Choose if you want warning alerts
   - **Info Messages** (Blue)
     - Choose if you want info notifications
4. **For each sensor type, toggle:**
   - Water Clarity alerts: ON/OFF
   - Temperature alerts: ON/OFF
   - pH alerts: ON/OFF
   - Dissolved Oxygen alerts: ON/OFF
   - And others...
5. **Set custom thresholds (if available):**
   - Tap on a sensor type
   - Set minimum safe value
   - Set maximum safe value
   - Example: pH should be between 6.5-8.0
6. **Choose notification delivery method:**
   - Push notification (in-app popup)
   - Email notification
   - Both
7. **Scroll down and tap "Save Preferences"**
8. **Confirmation message appears**
9. **Your alert settings are now customized**

### Logout - Step by Step

1. **On your Profile page, scroll all the way down**
2. **You'll see a red "Logout" or "Sign Out" button**
3. **Tap the "Logout" button**
4. **A confirmation popup appears:** "Are you sure you want to logout?"
5. **Tap "Yes" or "Logout"** to confirm
6. **App returns to the Welcome Screen**
7. **Your session is ended**
8. **To log back in:** Enter your email and password againo your email)
   - Both
9. **Select notification frequency:**
   - Alert immediately
   - Alert once per hour
   - Alert once per day
10. **Tap "Save" or "Apply"** to save your settingadings\*\*
    - **Trends over time**
    - **Date and time of each reading**
    - **Charts and graphs** (if available)

### Analyzing Trends

- **Look for patterns** in water quality over days/weeks
- **Compare values** to understand seasonal changes
- **Identify improvement areas** where values were previously unsafe

### Export Data (if available)

- Look for export options to save data as CSV or PDF
- Useful for reporting or further analysis

---

## Notifications

### Enable Notifications

1. **Tap the Notifications icon** 🔔 in the bottom navigation menu
2. You'll see alerts for:
   - **Out-of-range readings** - When sensors exceed safe limits
   - **System updates** - Important app announcements
   - **Maintenance alerts** - Sensor maintenance reminders
   - **Custom alerts** - Alerts you've set up in settings

### Understanding Notification Types

- 🔴 **Critical** - Immediate action required (sensor far outside range)
- 🟡 **Warning** - Monitor closely (sensor approaching limits)
- 🔵 **Info** - General information or updates
- ✅ **Resolved** - Previous alert is now resolved

### Managing Notifications

1. **Tap a notification** to view details
2. **Dismiss** by swiping or tapping close
3. **Take action** by following suggested steps in critical alerts

### Notification Settings (Profile)

- Go to **Profile → Notification Settings**
- Choose which alerts to receive
- Set alert thresholds

---

## Managing Your Profile

### Access Your Profile

1. **Tap the Profile icon** 👤 in the bottom navigation menu
2. You'll see:
   - **Your account information**
   - **Email address**
   - **Account settings**
   - **Preferences**

### Update Your Information

1. **Tap "Edit Profile"** or the edit icon
2. **Update your details**:
   - Display name
   - Contact information
   - Preferred units (metric/imperial)
3. **Save changes** - Tap the save button
4. **Confirm update** - You'll see a confirmation message

### Change Password

1. **From Profile, select "Change Password"**
2. **Enter your current password**
3. **Enter your new password** (twice for confirmation)
4. **Save changes**

### Notification Preferences

1. **Go to Profile → Notification Settings**
2. **Toggle alerts** on/off for different sensor types
3. **Set thresholds** for different alerts
4. **Choose notification method** (push notification, email, etc.)

### Logout

1. **From Profile, scroll to bottom**
2. **Tap "Logout"** or **"Sign Out"**
3. You'll be returned to the login screen
4. Your session will be cleared

---

## Understanding Water Quality Metrics

### Key Metrics Explained

#### **1. Water Clarity / Turbidity (NTU)**

- **What it measures**: How clear the water is
- **Safe Range**: 0-5 NTU (lower is better)
- **What it means**:
  - 0-1 NTU: Crystal clear
  - 1-5 NTU: Good clarity
  - 5+ NTU: Cloudy, suspended particles present

#### **2. Temperature (°C)**

- **What it measures**: Water temperature
- **Safe Range**: 10-25°C (varies by use)
- **What it means**:
  - Too cold: Fish stress, slow decomposition
  - Too hot: Reduced oxygen, algae growth
  - Optimal: 15-20°C for most aquatic life

#### **3. pH Level**

- **What it measures**: Acidity or alkalinity
- **Safe Range**: 6.5-7.5 (neutral)
- **What it means**:
  - <6.5: Too acidic (corrosive)
  - 6.5-7.5: Neutral (ideal)
  - > 7.5: Too alkaline (can affect taste, clarity)
  - 0: Extremely acidic
  - 14: Extremely alkaline

#### **4. Dissolved Oxygen (DO) (mg/L)**

- **What it measures**: Oxygen available for aquatic life
- **Safe Range**: 6-8 mg/L
- **What it means**:
  - <3 mg/L: Fish stress/death risk
  - 3-6 mg/L: Below optimal, problematic
  - 6-8 mg/L: Good for aquatic life
  - > 8 mg/L: Excellent

#### **5. Conductivity (μS/cm)**

- **What it measures**: Electrical conductivity (mineral/salt content)
- **Safe Range**: 200-1000 μS/cm (varies by region)
- **What it means**:
  - <200: Very low mineral content
  - 200-1000: Normal
  - > 1000: High salinity or mineral content

#### **6. Water Quality Index (WQI)**

- **What it measures**: Overall water quality on 0-100 scale
- **What it means**:
  - 0-25: Poor (🔴 Red)
  - 26-50: Fair (🟡 Yellow)
  - 51-75: Good (Light Green)
  - 76-100: Excellent (🟢 Green)

---

## Tips & Best Practices

### ✅ Do's

- ✅ Check your dashboard daily for water quality updates
- ✅ Enable notifications for critical alerts
- ✅ Review historical data to understand trends
- ✅ Keep your profile information updated
- ✅ Note patterns in seasonal changes
- ✅ Act promptly on critical alerts
- ✅ Keep your password secure

### ❌ Don'ts

- ❌ Ignore critical alert notifications
- ❌ Share your login credentials
- ❌ Rely solely on one sensor reading (check trends)
- ❌ Leave the app unattended during critical periods

---

## Troubleshooting

### No Sensor Data Showing

- **Check internet connection** - The app needs internet to fetch real-time data
- **Restart the app** - Close and reopen WATERGUARD
- **Check if sensors are active** - Ensure ESP32 sensors are powered on
- **Wait 1-2 minutes** - Initial connection may take time

### Login Issues

- **Verify email and password** - Check for typos
- **Reset password** - Use "Forgot Password?" feature
- **Contact support** - If issues persist

### Notifications Not Working

- **Check permissions** - Enable notifications in phone settings
- **App permissions** - Verify WATERGUARD has notification permission
- **Check settings** - Ensure alerts are enabled in Profile

### App Crashes

- **Update the app** - Ensure you have the latest version
- **Clear cache** - Go to phone settings → Apps → WATERGUARD → Clear Cache
- **Reinstall if needed** - Uninstall and reinstall the app

---

## FAQ

**Q: How often is the sensor data updated?**
A: Data updates in real-time as sensors transmit readings, typically every 1-2 minutes.

**Q: Can I view data from multiple water sources?**
A: Yes, if you have multiple sensors configured, each will appear as a separate device/location.

**Q: Is my data secure?**
A: Yes, all data is encrypted in transit and stored securely on our servers. See SECURITY.md for details.

**Q: Can I download historical data?**
A: Yes, from the History page, look for export options (CSV, PDF).

**Q: What if a reading seems incorrect?**
A: Check the sensor connection. In the History view, look for anomalies. If persistent, the sensor may need calibration.

**Q: How long is data retained?**
A: Historical data is retained for at least 2 years (depending on your plan).

**Q: Can I share alerts with other users?**
A: Check Profile → Sharing Settings for options to add family members or team members.

---

## Need Help?

- **In-app Help**: Look for the "?" icon in the app
- **Documentation**: Check the README.md file in the app directory
- **Backend API**: See API_DOCUMENTATION.md for technical details
- **ESP32 Setup**: Refer to ESP32_SETUP_GUIDE.md for sensor configuration

---

## Support

For issues, feature requests, or questions:

1. Check this tutorial
2. Review the FAQ section
3. Contact the development team
4. Check GitHub issues if available

---

**Last Updated**: June 2026
**Version**: 1.0
**WATERGUARD Team**
