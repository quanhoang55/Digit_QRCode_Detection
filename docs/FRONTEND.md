# FRONTEND — Local QR + Seven-Segment Digit Detection App

## 1. Frontend Overview

The frontend is the local control and monitoring interface for the computer-vision application.

Its main purpose is to allow an operator to:

1. View the live webcam feed.
2. See computer-vision detection results directly on top of the video.
3. See the decoded QR data.
4. See the detected seven-segment number.
5. Review the recognition result before saving.
6. Press **Save** to store the result in the database.
7. See recently saved records.

The frontend should remain simple and focused on the physical workflow.

The primary user flow is:

```text
Webcam
   ↓
Live Video
   ↓
CV Detection
   ↓
Detection Overlay
   ↓
QR + Numeric Result
   ↓
User Reviews Result
   ↓
[ SAVE ]
   ↓
Database
```

---

# 2. Main Screen

The application should have one primary screen.

Suggested layout:

```text
┌──────────────────────────────────────────────────────────────┐
│  QR + SEVEN-SEGMENT CAPTURE                                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                  LIVE CAMERA VIEW                            │
│                                                              │
│       ┌──────────────────────────────────────────┐           │
│       │                                          │           │
│       │       [ QR CODE ]                        │           │
│       │                                          │           │
│       │             ┌───┐ ┌───┐ ┌───┐ ┌───┐    │           │
│       │             │ 1 │ │ 2 │ │ 5 │ │ 0 │    │           │
│       │             └───┘ └───┘ └───┘ └───┘    │           │
│       │                                          │           │
│       └──────────────────────────────────────────┘           │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  QR DATA            DEVICE-001                               │
│  DETECTED VALUE     12.50                                    │
│  CONFIDENCE         91%                                      │
│  STATUS              READY TO SAVE                            │
│                                                              │
│                 ┌──────────────────┐                          │
│                 │       SAVE       │                          │
│                 └──────────────────┘                          │
├──────────────────────────────────────────────────────────────┤
│  RECENT RECORDS                                               │
│                                                              │
│  DEVICE-001       12.50       91%       12:01:22            │
│  DEVICE-002        8.75       95%       12:01:35            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

The camera should occupy the largest area of the screen because visual confirmation is the primary operator task.

---

# 3. Live Webcam View

## 3.1 Purpose

The frontend should display the same live camera feed being processed by the CV backend.

The user should not need to look at a separate camera application.

```text
Physical Camera
      ↓
Backend
      ↓
Live Frame
      ↓
Frontend
      ↓
Screen
```

The video should update continuously.

---

# 4. Detection Overlay

The frontend should display detection results directly on the camera image.

For example:

```text
┌───────────────────────────────────────────────┐
│                                               │
│     ┌─────────────┐                           │
│     │ QR CODE     │                           │
│     │             │                           │
│     └─────────────┘                           │
│                                               │
│                 ┌────┐ ┌────┐ ┌────┐ ┌────┐  │
│                 │  1 │ │  2 │ │  5 │ │  0 │  │
│                 └────┘ └────┘ └────┘ └────┘  │
│                                               │
└───────────────────────────────────────────────┘
```

For each digit detection, the overlay may show:

```text
┌───────┐
│   5   │
└───────┘
  0.94
```

Where:

```text
5    = detected class
0.94 = confidence
```

The frontend should not perform the detection itself.

The backend/CV engine provides the detection information.

---

# 5. Separation Between Video and Detection

The system should conceptually separate:

```text
Video Stream
```

from:

```text
Detection Metadata
```

Example:

```json
{
  "frame": "...",
  "detections": [
    {
      "type": "digit",
      "value": 1,
      "confidence": 0.98,
      "x": 120,
      "y": 100,
      "width": 30,
      "height": 60
    }
  ]
}
```

The frontend combines the video and metadata visually.

This allows the CV backend to remain independent from the frontend rendering system.

---

# 6. QR Detection Result

The frontend should display the decoded QR payload clearly.

Example:

```text
QR DATA

DEVICE-001
```

Possible states:

```text
WAITING FOR QR
```

```text
QR DETECTED

DEVICE-001
```

```text
QR ERROR

Unable to decode QR
```

The frontend should not display stale QR information as if it were current.

---

# 7. Digit Detection Result

The frontend should display both the individual detections and the reconstructed number.

Example:

```text
DETECTED DIGITS

1   2   5   0

VALUE

12.50
```

The reconstructed value should be visually more prominent than the individual digits.

---

# 8. Recognition Status

The frontend should clearly communicate the current state.

Suggested states:

```text
WAITING
```

Meaning:

```text
No valid recognition yet.
```

---

```text
DETECTING
```

Meaning:

```text
The CV pipeline is currently processing frames.
```

---

```text
READY TO SAVE
```

Meaning:

```text
QR + numeric value have been successfully recognized
and passed validation.
```

---

```text
SAVED
```

Meaning:

```text
The current recognition result was successfully
written to the database.
```

---

```text
LOW CONFIDENCE
```

Meaning:

```text
The system detected something, but confidence is
below the configured threshold.
```

---

```text
INCOMPLETE
```

Meaning:

```text
QR or digit information is missing.
```

---

```text
ERROR
```

Meaning:

```text
An application or backend error occurred.
```

---

# 9. Save Button

The **Save** button is the primary user action.

The button should only become active when the recognition result is valid.

Example:

```text
QR DATA
DEVICE-001

VALUE
12.50

STATUS
READY TO SAVE

[ SAVE ]
```

Before recognition:

```text
QR DATA
Waiting...

VALUE
Waiting...

STATUS
WAITING

[ SAVE ]  ← disabled
```

When the result is invalid:

```text
STATUS
INCOMPLETE

[ SAVE ]  ← disabled
```

When saving:

```text
[ SAVING... ]
```

After successful saving:

```text
[ SAVED ]
```

The button should not allow multiple simultaneous save requests.

---

# 10. Save Workflow

When the user presses **SAVE**:

```text
User clicks SAVE
       ↓
Frontend validates current state
       ↓
POST /measurements
       ↓
Backend validates again
       ↓
Database INSERT
       ↓
Backend returns saved record
       ↓
Frontend displays success
       ↓
Record appears in Recent Records
```

Example request:

```json
{
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.50,
  "confidence": 0.91
}
```

Example response:

```json
{
  "id": 42,
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.50,
  "confidence": 0.91,
  "created_at": "2026-09-29T12:01:22Z"
}
```

---

# 11. Backend Validation

The frontend should perform basic validation for UX.

However, the backend must remain the authoritative validation layer.

Frontend:

```text
Is QR present?
Is numeric value present?
Is status READY?
Is a save request already running?
```

Backend:

```text
Is the payload valid?
Are the values correctly formatted?
Is the record a duplicate?
Can the database accept it?
```

The frontend must never assume that a successful button click means the database write succeeded.

---

# 12. Recent Records

The bottom section should show recently saved records.

Example:

```text
RECENT RECORDS

┌──────────────┬────────┬────────────┬──────────┐
│ QR DATA      │ VALUE  │ CONFIDENCE │ TIME     │
├──────────────┼────────┼────────────┼──────────┤
│ DEVICE-001   │ 12.50  │ 91%        │ 12:01:22 │
│ DEVICE-002   │  8.75  │ 95%        │ 12:01:35 │
│ DEVICE-003   │ 24.10  │ 89%        │ 12:02:01 │
└──────────────┴────────┴────────────┴──────────┘
```

The list should update after a successful save.

The frontend can initially display only the latest 10–20 records.

---

# 13. Frontend State

The application should maintain a small amount of UI state.

Example:

```text
cameraStatus
recognitionStatus
qrData
detectedDigits
numericValue
confidence
isSaving
saveError
recentRecords
```

Possible state:

```json
{
  "cameraStatus": "CONNECTED",
  "recognitionStatus": "READY_TO_SAVE",
  "qrData": "DEVICE-001",
  "detectedDigits": [1, 2, 5, 0],
  "numericValue": 12.50,
  "confidence": 0.91,
  "isSaving": false
}
```

---

# 14. Camera Connection State

The frontend should handle camera failures.

Possible states:

```text
CONNECTING
CONNECTED
DISCONNECTED
ERROR
```

Example:

```text
┌──────────────────────────────────────────────┐
│                                              │
│           CAMERA DISCONNECTED               │
│                                              │
│             [ RECONNECT ]                   │
│                                              │
└──────────────────────────────────────────────┘
```

The application should not show an empty black camera area without explaining what happened.

---

# 15. Detection Overlay Data

The backend should provide coordinates for detected objects.

Example:

```json
{
  "detections": [
    {
      "type": "digit",
      "class": 1,
      "confidence": 0.98,
      "bbox": {
        "x": 120,
        "y": 150,
        "width": 40,
        "height": 80
      }
    }
  ]
}
```

The frontend converts these coordinates to the displayed video dimensions.

Important:

```text
Camera resolution
        ↓
Backend coordinates
        ↓
Frontend video scaling
        ↓
Overlay coordinates
```

The overlay must account for:

- Video scaling.
- Aspect ratio.
- Letterboxing/pillarboxing.
- Different camera resolutions.
- Browser/window resizing.

---

# 16. Video Transport

The frontend needs a way to receive the live camera feed.

Possible approaches:

## Option A — MJPEG

```text
Backend
   ↓
MJPEG stream
   ↓
Frontend <img>/<video-compatible viewer>
```

Advantages:

- Simple.
- Easy to implement.
- Suitable for an initial local prototype.

## Option B — WebRTC

```text
Camera
   ↓
Backend
   ↓
WebRTC
   ↓
Frontend
```

Advantages:

- Lower latency.
- Better real-time video architecture.

However, it adds more complexity.

## Initial Recommendation

Use the simplest local streaming mechanism that satisfies the prototype.

The architecture should keep the video transport replaceable so that MJPEG can later be replaced with WebRTC without rewriting the recognition logic.

---

# 17. Detection Metadata Transport

Detection results can be transmitted separately from the video.

Possible approach:

```text
Video:
HTTP/MJPEG

Detection:
WebSocket
```

Example:

```text
Frontend
   │
   ├──────────► Video Stream
   │
   └──────────► WebSocket
                    │
                    ▼
              Detection Events
```

WebSocket message:

```json
{
  "type": "detection",
  "timestamp": 1727611200000,
  "qr": {
    "data": "DEVICE-001"
  },
  "digits": [
    {
      "class": 1,
      "confidence": 0.98,
      "bbox": [120, 150, 40, 80]
    },
    {
      "class": 2,
      "confidence": 0.97,
      "bbox": [165, 150, 40, 80]
    }
  ],
  "raw_digits": "12",
  "numeric_value": 12,
  "confidence": 0.97,
  "status": "DETECTING"
}
```

---

# 18. Recommended Frontend Architecture

The frontend can be divided into:

```text
src/
│
├── components/
│   ├── CameraView
│   ├── DetectionOverlay
│   ├── RecognitionPanel
│   ├── SaveButton
│   ├── StatusIndicator
│   └── RecentRecords
│
├── services/
│   ├── camera
│   ├── websocket
│   └── api
│
├── hooks/
│   ├── useCamera
│   ├── useDetection
│   └── useMeasurements
│
├── types/
│   └── recognition
│
└── App
```

The exact framework can be selected separately.

---

# 19. Component Responsibilities

## CameraView

Responsible for:

- Displaying the live camera stream.
- Handling camera connection state.
- Reporting video dimensions.

It should not contain database logic.

---

## DetectionOverlay

Responsible for:

- Drawing QR bounding boxes.
- Drawing digit bounding boxes.
- Displaying confidence.
- Mapping backend coordinates to frontend coordinates.

It should receive detection data as props/state.

---

## RecognitionPanel

Responsible for:

- QR data.
- Detected digits.
- Numeric value.
- Confidence.
- Recognition status.

Example:

```text
QR DATA
DEVICE-001

VALUE
12.50

CONFIDENCE
91%

STATUS
READY TO SAVE
```

---

## SaveButton

Responsible for:

- Enabling/disabling save.
- Showing loading state.
- Sending the save request.
- Showing save success/failure.

It should not implement CV logic.

---

## RecentRecords

Responsible for:

- Fetching recent database records.
- Displaying saved measurements.
- Refreshing after a successful save.

---

# 20. Main Frontend Data Flow

```text
                 Backend
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
      Video Stream       Detection Events
          │                   │
          ▼                   ▼
     CameraView        DetectionOverlay
                              │
                              ▼
                      RecognitionPanel
                              │
                              ▼
                         SaveButton
                              │
                              ▼
                         REST API
                              │
                              ▼
                         Database
                              │
                              ▼
                      RecentRecords
```

---

# 21. UI Interaction Rules

### Rule 1

The user should always be able to see the camera.

### Rule 2

Detection results should appear without requiring the user to press a button.

### Rule 3

The Save button should only be enabled for a valid recognition result.

### Rule 4

Saving should be an explicit user action in the MVP.

### Rule 5

After saving, the saved record should immediately appear in the recent-record list.

### Rule 6

A failed save should not clear the current recognition result.

### Rule 7

A successful save may reset the recognition state for the next object.

---

# 22. Successful Save Flow

Example:

```text
Camera:
DEVICE-001 / 12.50

        ↓

Frontend:
QR: DEVICE-001
Value: 12.50
Confidence: 91%
Status: READY TO SAVE

        ↓

User clicks SAVE

        ↓

Backend:
INSERT measurement

        ↓

Frontend:

Status:
SAVED

        ↓

Recent Records:

DEVICE-001    12.50    91%    12:01:22
```

After a short delay or explicit reset:

```text
WAITING FOR NEXT OBJECT
```

---

# 23. Failed Save Flow

Example:

```text
User clicks SAVE
        ↓
POST /measurements
        ↓
Backend error
        ↓
Frontend
        ↓
"Failed to save measurement"
```

The recognition result remains visible:

```text
QR:
DEVICE-001

VALUE:
12.50

STATUS:
SAVE FAILED

[ RETRY ]
```

This prevents the operator from losing the result.

---

# 24. UX Priority

The interface should prioritize:

```text
1. Camera visibility
2. Recognition result
3. Save action
4. Recognition status
5. Recent history
```

The user should be able to understand the entire state of the system within a few seconds.

Avoid unnecessary dashboards, charts, settings, or navigation in the MVP.

---

# 25. MVP Frontend

The MVP requires only:

```text
┌──────────────────────────────────────────┐
│              CAMERA VIEW                 │
│                                          │
│       QR + DIGIT DETECTION OVERLAY       │
│                                          │
└──────────────────────────────────────────┘

QR:
DEVICE-001

VALUE:
12.50

CONFIDENCE:
91%

STATUS:
READY TO SAVE

             [ SAVE ]

RECENT RECORDS
--------------------------------------------
DEVICE-001     12.50     12:01:22
DEVICE-002      8.75     12:01:35
```

This is enough for the first usable version.

---

# 26. MVP Technical Flow

```text
Camera
  ↓
Backend CV pipeline
  ↓
Video stream ───────────────► CameraView
  │
  └─ Detection metadata ────► DetectionOverlay
                                  │
                                  ▼
                           RecognitionPanel
                                  │
                                  ▼
                             Save Button
                                  │
                                  ▼
                         POST /measurements
                                  │
                                  ▼
                              Database
                                  │
                                  ▼
                           Recent Records
```

---

# 27. Future Frontend Features

After the MVP works, possible additions include:

- Automatic save mode.
- Manual correction of detected digits.
- Capture screenshot.
- Full measurement history.
- Search by QR code.
- Filtering by date.
- Export CSV.
- Device profiles.
- Camera selection.
- Confidence threshold settings.
- Detection FPS.
- System health status.
- Database statistics.
- Multiple camera support.
- Dark/light theme.
- Full-screen operation mode.

These should not be required for the initial implementation.

---

# 28. Final Frontend Goal

The final interaction should feel like a simple industrial capture station:

```text
                CAMERA
                   │
                   ▼
        ┌─────────────────────┐
        │  Live video         │
        │                     │
        │  QR detected        │
        │  1 2 5 0 detected   │
        └─────────────────────┘

QR DATA
DEVICE-001

VALUE
12.50

CONFIDENCE
91%

STATUS
READY TO SAVE

          ┌───────────┐
          │   SAVE    │
          └───────────┘

After save:

STATUS
SAVED ✓

RECENT RECORD
DEVICE-001 → 12.50
```

The frontend's job is therefore not to perform computer vision itself.

Its job is to provide a clear real-time window into the CV system and give the operator one explicit action:

**review the detected result → press SAVE → persist the record.**
