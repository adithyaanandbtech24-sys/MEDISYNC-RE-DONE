# MediSync Testing Guide

## Overview
This guide will help you test all features of the MediSync medical app, including upload, analysis, and graph visualization.

---

## 1. Testing Graph Visualization (Quick Start)

### Generate Sample Data
1. **Launch the app**
2. **Go to Dashboard** (Home tab)
3. **Tap the GREEN chart icon** (📊) in the top-right header
4. **Wait 2 seconds** for data generation
5. **Scroll to "Vitals & Lab Results"** section
6. **Verify graphs appear** in both:
   - 🟠 **Lungs card** (orange) - Should show SpO2 and Respiratory Rate trends
   - 🔵 **Heart card** (blue) - Should show Heart Rate and Blood Pressure trends

### Expected Results
- ✅ Mini-graphs with white lines visible in dashboard cards
- ✅ Smooth, curved lines (not jagged)
- ✅ No "No Data Available" message
- ✅ Tapping cards opens detailed view with full charts

---

## 2. Testing Document Upload & Analysis

### A. Image Upload Test

1. **Prepare Test Image**
   - Take a screenshot of `TEST_MEDICAL_REPORT.txt`
   - OR use any medical lab report photo you have

2. **Upload Process**
   - Tap **Upload** button (📁) in bottom navigation
   - Tap **"Take Photo or Select Image"**
   - Select your test image
   - Enter title: "Test Lab Report"
   - Tap **"Upload Document"** button

3. **Expected Results**
   - ✅ Upload progress bar appears
   - ✅ "Document uploaded successfully!" message
   - ✅ Auto-switches to **Chatbot tab**
   - ✅ Chatbot asks: "Would you like me to analyze this report?"
   - ✅ Dashboard graphs update with new data

### B. PDF Upload Test

1. **Prepare Test PDF**
   - Convert `TEST_MEDICAL_REPORT.txt` to PDF
   - OR use any medical PDF report

2. **Upload Process**
   - Tap **Upload** button (📁)
   - Tap **"Upload PDF Report"**
   - Select your PDF file
   - Enter title: "Test PDF Report"
   - Auto-uploads immediately

3. **Expected Results**
   - ✅ Upload progress appears
   - ✅ Success message shown
   - ✅ Auto-switches to Chatbot
   - ✅ Analysis begins automatically

### C. What Gets Analyzed

The ML algorithm extracts:

**Vital Signs:**
- ❤️ Heart Rate (60-100 BPM)
- 🫁 SpO2 (95-100%)
- 🌬️ Respiratory Rate (12-20 breaths/min)
- 🩺 Blood Pressure (Systolic/Diastolic)
- 🌡️ Temperature

**Blood Tests:**
- Hemoglobin, Hematocrit, RBC, WBC, Platelets

**Metabolic:**
- Glucose, HbA1c

**Lipids:**
- Cholesterol, HDL, LDL, Triglycerides

**Kidney:**
- Creatinine, BUN, eGFR

**Liver:**
- ALT, AST, ALP, Bilirubin

**Thyroid:**
- TSH, T3, T4

**Vitamins:**
- Vitamin D, B12, Iron, Ferritin

---

## 3. Testing Chatbot Analysis

### After Upload

1. **Chatbot Auto-Opens**
2. **Sends Analysis Prompt** (automatic)
3. **AI Generates Summary** including:
   - 📊 Critical values
   - 🔍 Key findings
   - 💊 Medication recommendations
   - ⚠️ Values outside normal range

### Manual Analysis Request

Type these questions to test AI:
- "Summarize my latest lab results"
- "What are my critical values?"
- "Any abnormal results?"
- "Suggest improvements"

---

## 4. Testing Medication Reminders

1. **In Chatbot**, type: "Set medication reminder"
2. **Reminder Sheet Opens**
3. **Fill in:**
   - Medication name
   - Time for reminder
4. **Tap "Set Reminder"**
5. **Grant notification permission** (if prompted)

### Expected Results
- ✅ Notification scheduled
- ✅ Success message
- ✅ Reminder appears in system at specified time

---

## 5. Testing Graph Details

### Full Graph View

1. **Tap any organ card** (Lungs, Heart, Kidneys, Liver)
2. **View opens** with:
   - 📊 Large interactive chart
   - 📈 Latest value display
   - ✅/❌ Normal vs Abnormal indicator
   - 📜 Recent history list
   - 🎯 Reference lines (normal ranges)

### Verify Graph Features
- ✅ Smooth curved lines (catmull-rom interpolation)
- ✅ Gradient fill under curves
- ✅ X-axis shows dates
- ✅ Y-axis shows values with units
- ✅ Dotted reference line for normal average
- ✅ Color matches organ card color

---

## 6. Known Test Data Values

### Sample Data Generated (Ranges)

**Heart:**
- Heart Rate: 65-85 BPM
- Blood Pressure Systolic: 110-125 mmHg

**Lungs:**
- SpO2: 96-99%
- Respiratory Rate: 14-18 breaths/min

**Kidneys:**
- Creatinine: 0.8-1.1 mg/dL
- eGFR: 95-110 mL/min

**Liver:**
- ALT: 20-35 U/L
- AST: 18-32 U/L

---

## 7. Troubleshooting

### Graphs Not Showing
- ✅ Tap green chart button to generate sample data
- ✅ Wait 2-3 seconds for data to load
- ✅ Scroll to refresh view
- ✅ Upload a real medical report

### PDF Not Uploading
- ✅ Ensure PDF is readable (not encrypted)
- ✅ Check file size (should be <10 MB)
- ✅ Verify PDF contains actual text (not scanned image)
- ✅ Check console logs for error messages

### No Analysis from Chatbot
- ✅ Check notification permission granted
- ✅ Verify document uploaded successfully
- ✅ Manually type "Analyze my latest report"
- ✅ Check internet connection

### OCR Not Extracting Text
- ✅ Use clear, high-contrast images
- ✅ Ensure text is legible
- ✅ Try PDF instead of image
- ✅ Check TEST_MEDICAL_REPORT.txt format

---

## 8. Indian Medical Standards Reference

All comparisons use official Indian medical ranges:

| Parameter | Normal Range | Unit |
|-----------|-------------|------|
| Heart Rate | 60-100 | BPM |
| SpO2 | 95-100 | % |
| BP Systolic | 90-120 | mmHg |
| BP Diastolic | 60-80 | mmHg |
| Creatinine | 0.6-1.2 | mg/dL |
| eGFR | 90-120 | mL/min |
| ALT | 7-55 | U/L |
| AST | 8-48 | U/L |
| Hemoglobin | 12-17 | g/dL |
| Glucose (Fasting) | 70-100 | mg/dL |

---

## 9. Performance Benchmarks

**Upload Speed:**
- Image: 2-5 seconds
- PDF: 3-7 seconds

**OCR Processing:**
- Image: 5-10 seconds
- PDF: 3-8 seconds

**ML Analysis:**
- Text extraction: 1-3 seconds
- Metric parsing: 2-5 seconds

**Total Time (Upload → Graph):**
- Expected: 10-20 seconds
- Maximum: 30 seconds

---

## 10. Test Checklist

### Before Release
- [ ] Sample data generates graphs
- [ ] Image upload works
- [ ] PDF upload works
- [ ] OCR extracts text correctly
- [ ] ML finds all metrics in test report
- [ ] Graphs show correct values
- [ ] Chatbot receives upload notification
- [ ] Chatbot generates analysis
- [ ] Medication reminders work
- [ ] All organ cards clickable
- [ ] Full graph view displays correctly
- [ ] Indian standards comparison accurate
- [ ] No console errors during upload
- [ ] No memory leaks after multiple uploads

---

## Support

For issues or questions:
1. Check console logs (Xcode)
2. Verify test data format
3. Review `ReportService` logs (look for 🔍 emoji)
4. Check `MLService` parsing (look for 📊 emoji)

**Happy Testing! 🧪**
