# IDEA — Local QR + Seven-Segment Digit Data Capture System

## 1. Project Overview

### 1.1 Project Name

**Local QR + Seven-Segment Digit Data Capture System**

A local computer-vision application that captures information from a physical object or measurement device using a camera.

The application combines two independent recognition tasks:

1. **QR code scanning** — identifies the object, device, package, or measurement session.
2. **Seven-segment digit detection** — reads a numeric value displayed on a seven-segment display.

The system then combines both results into one structured record and stores it in a local database.

### 1.2 Core Idea

The application receives a camera frame containing:

- A QR code containing an identifier.
- A seven-segment display containing a numeric value.

The CV pipeline extracts both pieces of information:

```text
Camera
  │
  ▼
Frame
  │
  ├──► QR Detection / Decoding
  │       │
  │       ▼
  │     QR Data
  │
  └──► Seven-Segment Detection
          │
          ├──► Digit 0
          ├──► Digit 1
          ├──► Digit 2
          └──► ...
                  │
                  ▼
          Ordered Numeric Value
                  │
                  ▼
          Data Aggregation
                  │
                  ▼
             Database
```

The application is intended to run **locally**, without requiring a cloud CV service.

---

# 2. Problem Statement

Many physical workflows still require operators to manually read values from displays and manually associate those values with an object, product, package, machine, or measurement record.

A typical workflow may look like:

```text
Scan object
    ↓
Read QR code
    ↓
Look at digital display
    ↓
Read number manually
    ↓
Type number into software
    ↓
Save record
```

This introduces several potential problems:

- Manual transcription errors.
- Slow data entry.
- Difficulty processing many objects.
- Human inconsistency when reading displays.
- Separation between object identification and measurement data.
- Lack of automatic traceability.

The proposed system automates this process:

```text
Object
  ↓
Camera
  ↓
QR + Digit Recognition
  ↓
Structured Data
  ↓
Database
```

---

# 3. Project Goals

## 3.1 Primary Goals

The system should:

- Capture frames from a local camera.
- Detect and decode QR codes.
- Detect seven-segment digits using a trained object-detection model.
- Reconstruct the complete numeric value from individual digit detections.
- Associate the QR result with the numeric result.
- Validate the recognition results.
- Store the final structured record in a database.
- Operate locally with minimal external dependencies.
- Provide a simple interface for monitoring recognition results.

## 3.2 Secondary Goals

The system should eventually support:

- Continuous camera operation.
- Automatic recognition without manual triggering.
- Duplicate detection.
- Recognition confidence thresholds.
- Multiple objects over time.
- Recognition history.
- Error logging.
- Manual correction.
- Exporting records.
- Camera/device configuration.
- Basic statistics.

## 3.3 Non-Goals for the First Version

The first version does not need:

- Cloud-based inference.
- Large distributed infrastructure.
- Mobile applications.
- Complex user management.
- Advanced analytics.
- Real-time cloud synchronization.
- General OCR for arbitrary text.

The first version should focus on making the following pipeline reliable:

```text
Camera → QR + Seven-Segment Detection → Structured Record → Database
```

---

# 4. Target Use Case

The initial use case is a physical device or station where a camera can simultaneously observe:

- An identifying QR code.
- A numeric seven-segment display.

For example:

```text
+-----------------------------------+
|                                   |
|       SEVEN-SEGMENT DISPLAY       |
|              12.50                |
|                                   |
|          [ QR CODE ]              |
|                                   |
+-----------------------------------+
```

The application should produce:

```json
{
  "qr_data": "DEVICE-001",
  "value": 12.50,
  "raw_digits": "1250",
  "timestamp": "2026-09-29T12:00:00Z"
}
```

and save it to the database.

---

# 5. Functional Requirements

## FR-01 — Camera Capture

The application shall:

- Connect to a local camera.
- Capture frames continuously.
- Process frames at a configurable rate.
- Display the current camera frame.

Example:

```text
Camera
  ↓
Frame 1
Frame 2
Frame 3
...
```

The system does not necessarily need to run inference on every camera frame.

---

## FR-02 — QR Code Detection

The system shall detect QR codes in camera frames.

The QR pipeline should:

1. Locate the QR code.
2. Decode the QR payload.
3. Validate the payload.
4. Return structured QR information.

Example:

```text
QR image
    ↓
QR decoder
    ↓
"DEVICE-001"
```

The QR decoder should be independent from the digit-detection model.

---

## FR-03 — Seven-Segment Digit Detection

The system shall detect individual digits displayed on a seven-segment display.

The initial classes are:

```text
0
1
2
3
4
5
6
7
8
9
```

The digit detector should produce detections such as:

```text
class   confidence   bounding box
----------------------------------
1       0.98         (...)
2       0.96         (...)
5       0.94         (...)
0       0.91         (...)
```

---

## FR-04 — Digit Ordering

Detected digits are independent objects.

Therefore, the system must reconstruct the number according to their spatial order.

For a left-to-right display:

```text
Detected objects:

5    2    7    0
│    │    │    │
▼    ▼    ▼    ▼

"5270"
```

The basic algorithm is:

```text
1. Detect all digits.
2. Obtain each bounding box.
3. Calculate the horizontal center.
4. Sort detections by X coordinate.
5. Convert class IDs to digit characters.
6. Concatenate the characters.
```

Pseudo-code:

```python
detections.sort(key=lambda detection: detection.center_x)

digits = [
    detection.class_id
    for detection in detections
]

value = "".join(map(str, digits))
```

---

# 6. Decimal Point and Numeric Formatting

The first model focuses on digit recognition.

Decimal-point handling should be treated as a separate problem.

Possible future approaches:

### Approach A — Dedicated decimal-point class

Add:

```text
decimal_point
```

to the detection model.

Example:

```text
12.50

detections:
1
2
.
5
0
```

### Approach B — Fixed display configuration

If the physical device always displays a value in a known format, the application can reconstruct the decimal position using configuration.

Example:

```text
display_format = "XX.XX"
```

Then:

```text
1250 → 12.50
```

The first version should use the simplest format that matches the target hardware.

---

# 7. Recognition Pipeline

The complete processing pipeline is:

```text
                ┌──────────────────┐
                │      Camera      │
                └────────┬─────────┘
                         │
                         ▼
                ┌──────────────────┐
                │   Frame Capture  │
                └────────┬─────────┘
                         │
                 ┌───────┴────────┐
                 │                │
                 ▼                ▼
          ┌─────────────┐  ┌───────────────┐
          │ QR Decoder  │  │ Digit Detector│
          └──────┬──────┘  └───────┬───────┘
                 │                 │
                 ▼                 ▼
             QR Data        Digit Detections
                                   │
                                   ▼
                            Sort by X Position
                                   │
                                   ▼
                            Reconstruct Number
                                   │
                 ┌─────────────────┘
                 │
                 ▼
          ┌──────────────────┐
          │ Data Aggregation  │
          └────────┬─────────┘
                   │
                   ▼
          ┌──────────────────┐
          │ Validation Layer │
          └────────┬─────────┘
                   │
                   ▼
          ┌──────────────────┐
          │ Local Database   │
          └──────────────────┘
```

---

# 8. Recognition State

The application should not immediately save every partial recognition.

A recognition session can have states:

```text
WAITING
   ↓
QR_DETECTED
   ↓
DIGITS_DETECTED
   ↓
VALIDATING
   ↓
READY_TO_SAVE
   ↓
SAVED
```

Failure states:

```text
QR_NOT_FOUND
DIGITS_NOT_FOUND
LOW_CONFIDENCE
INVALID_VALUE
DUPLICATE
```

Example:

```text
QR:       DEVICE-001       ✓
Digits:   1250             ✓
Confidence: 0.94           ✓
Validation: PASS           ✓

Result:
DEVICE-001 → 12.50
```

---

# 9. Confidence and Validation

Recognition should not rely only on whether an object was detected.

Each digit has a confidence score.

Example:

```text
1 → 0.98
2 → 0.97
5 → 0.91
0 → 0.95
```

The application can calculate an aggregate confidence.

A simple initial strategy:

```text
record_confidence = minimum digit confidence
```

For example:

```text
min(0.98, 0.97, 0.91, 0.95)
= 0.91
```

Then:

```text
if confidence >= threshold:
    accept
else:
    reject / wait for another frame
```

The threshold should be configurable rather than hard-coded into the architecture.

---

# 10. Temporal Stabilization

A single camera frame may produce an incorrect result.

Instead of saving immediately, the application should eventually compare results across multiple consecutive frames.

Example:

```text
Frame 1 → DEVICE-001 → 1250
Frame 2 → DEVICE-001 → 1250
Frame 3 → DEVICE-001 → 1250
Frame 4 → DEVICE-001 → 1250
```

If the same result is detected consistently:

```text
1250
1250
1250
1250
 ↓
Stable recognition
 ↓
Save
```

This reduces accidental database writes caused by one bad frame.

A future configuration could define:

```text
required_stable_frames = 3
```

---

# 11. Duplicate Prevention

The system should prevent repeatedly saving the same object/value while the camera remains pointed at it.

Example:

```text
Frame 1 → DEVICE-001 / 12.50
Frame 2 → DEVICE-001 / 12.50
Frame 3 → DEVICE-001 / 12.50
Frame 4 → DEVICE-001 / 12.50
```

This should normally result in one database record, not four.

Possible duplicate policy:

```text
same QR
+
same value
+
within configured time window
=
duplicate
```

The duplicate window should be configurable.

---

# 12. Data Model

A minimal database can start with one primary table.

## 12.1 Measurement Record

```text
measurement
--------------------------------
id
qr_data
raw_digits
numeric_value
confidence
captured_at
created_at
```

Suggested types:

```text
id              INTEGER / UUID
qr_data         TEXT
raw_digits      TEXT
numeric_value   DECIMAL / FLOAT
confidence      FLOAT
captured_at     TIMESTAMP
created_at      TIMESTAMP
```

Example:

```json
{
  "id": 1,
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.50,
  "confidence": 0.91,
  "captured_at": "2026-09-29T12:00:00Z"
}
```

---

# 13. Database Design

For the first prototype:

```text
Application
     │
     ▼
Local Database
```

SQLite is a suitable first database because:

- It is local.
- It requires no database server.
- It is easy to deploy.
- It is sufficient for a local prototype.
- It can later be replaced or supplemented by PostgreSQL if required.

Possible SQLite schema:

```sql
CREATE TABLE measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    qr_data TEXT NOT NULL,
    raw_digits TEXT NOT NULL,
    numeric_value REAL,
    confidence REAL NOT NULL,
    captured_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);
```

---

# 14. System Architecture

The application should be divided into independent components.

```text
app/
│
├── camera/
│   └── frame capture
│
├── qr/
│   └── QR detection and decoding
│
├── digit_detection/
│   ├── model loading
│   ├── inference
│   └── post-processing
│
├── recognition/
│   ├── digit ordering
│   ├── number reconstruction
│   ├── confidence calculation
│   └── temporal stabilization
│
├── aggregation/
│   └── QR + numeric result
│
├── validation/
│   └── validation rules
│
├── database/
│   ├── connection
│   ├── models
│   └── repositories
│
├── api/
│   └── local API
│
└── ui/
    └── local monitoring interface
```

The exact programming language can be selected independently of the architecture.

---

# 15. Recommended Technology Direction

## Computer Vision

### Seven-Segment Detection

Use an object-detection model trained specifically for the target display.

Initial model:

```text
YOLO
```

Classes:

```text
0–9
```

The model should output:

```text
class
confidence
bounding box
```

### QR

Use a dedicated QR decoder rather than training the digit detector to recognize QR codes.

Possible libraries include:

- OpenCV QRCodeDetector
- ZXing
- ZBar
- Other platform-native QR decoders

The QR component should expose a simple interface to the rest of the application:

```text
decode(frame)
    ↓
QRResult | None
```

---

# 16. Model Training Pipeline

The digit detector requires a dataset representing the real target display.

Training workflow:

```text
Dataset
   ↓
Label validation
   ↓
Train / validation split
   ↓
YOLO training
   ↓
Validation
   ↓
Test on real camera images
   ↓
Export model
   ↓
Local inference
```

Dataset labels use YOLO format:

```text
class_id center_x center_y width height
```

All coordinates are normalized to:

```text
0.0 → 1.0
```

Initial classes:

```text
0
1
2
3
4
5
6
7
8
9
```

---

# 17. Dataset Quality Requirements

The model should eventually be trained on images that represent real operating conditions.

Important variations include:

- Different distances.
- Different camera angles.
- Different brightness.
- Reflections.
- Shadows.
- Different display colors.
- Motion blur.
- Partial obstruction.
- Different digit sizes.
- Different backgrounds.
- Different display hardware.

The dataset should not consist only of perfectly clean screenshots.

The most important dataset is the one that resembles the actual deployment environment.

---

# 18. Inference Pipeline

At runtime:

```text
Camera Frame
     │
     ├───────────────┐
     │               │
     ▼               ▼
QR Decoder       YOLO Detector
     │               │
     ▼               ▼
QR Result       Bounding Boxes
                     │
                     ▼
                Post-process
                     │
                     ▼
                 Sort Digits
                     │
                     ▼
               Reconstruct Value
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
       QR Data              Numeric Value
          │                     │
          └──────────┬──────────┘
                     ▼
               Validation
                     │
                     ▼
                  Database
```

---

# 19. Post-Processing

The raw YOLO output should not directly become a database record.

The post-processing layer should:

1. Remove low-confidence detections.
2. Remove invalid classes.
3. Apply non-maximum suppression through the detector pipeline.
4. Calculate object centers.
5. Sort digits.
6. Detect possible duplicate digit boxes.
7. Construct the raw digit string.
8. Apply numeric formatting.
9. Calculate aggregate confidence.
10. Return a structured recognition result.

Example internal object:

```json
{
  "digits": [
    {
      "digit": 1,
      "confidence": 0.98,
      "center_x": 120
    },
    {
      "digit": 2,
      "confidence": 0.97,
      "center_x": 145
    },
    {
      "digit": 5,
      "confidence": 0.91,
      "center_x": 170
    },
    {
      "digit": 0,
      "confidence": 0.95,
      "center_x": 195
    }
  ],
  "raw_digits": "1250",
  "confidence": 0.91
}
```

---

# 20. Aggregated Result

The aggregation layer combines independent recognition results.

Input:

```json
{
  "qr": {
    "data": "DEVICE-001"
  },
  "digits": {
    "raw_digits": "1250",
    "value": 12.50,
    "confidence": 0.91
  }
}
```

Output:

```json
{
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.50,
  "confidence": 0.91
}
```

This object becomes the boundary between computer vision and database persistence.

---

# 21. Local API

Even though the application runs locally, separating the CV engine from the UI is useful.

Possible local API:

```text
GET  /health
GET  /status

POST /capture
POST /recognition/process

GET  /measurements
GET  /measurements/{id}
DELETE /measurements/{id}
```

Example:

```text
POST /recognition/process
```

Response:

```json
{
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.50,
  "confidence": 0.91,
  "status": "READY_TO_SAVE"
}
```

---

# 22. User Interface

The first UI should be simple.

Suggested layout:

```text
+------------------------------------------------+
|              LOCAL CV CAPTURE                  |
+------------------------------------------------+
|                                                |
|              CAMERA PREVIEW                   |
|                                                |
|        [ QR ]       [ 1 2 . 5 0 ]             |
|                                                |
+------------------------------------------------+
| QR:          DEVICE-001                       |
| Value:       12.50                            |
| Confidence:  91%                               |
| Status:      READY                            |
+------------------------------------------------+
|                 [ SAVE ]                      |
+------------------------------------------------+
| Recent Records                                 |
| DEVICE-001     12.50     12:01:22             |
| DEVICE-002      8.75     12:01:35             |
+------------------------------------------------+
```

The UI is primarily for:

- Monitoring.
- Debugging.
- Manual confirmation.
- Reviewing saved records.

The core CV pipeline should not depend on the UI.

---

# 23. Error Handling

The application should distinguish between different failure conditions.

## QR Failure

```text
QR_NOT_FOUND
QR_DECODE_FAILED
QR_INVALID
```

## Digit Failure

```text
NO_DIGITS
LOW_CONFIDENCE
INVALID_DIGIT_SEQUENCE
TOO_MANY_DIGITS
```

## Aggregation Failure

```text
QR_MISSING
VALUE_MISSING
INCOMPLETE_RECOGNITION
```

## Database Failure

```text
DATABASE_CONNECTION_ERROR
DATABASE_WRITE_ERROR
DUPLICATE_RECORD
```

This makes debugging significantly easier than returning one generic error.

---

# 24. Logging

The system should produce structured logs.

Example:

```text
INFO  Camera connected
INFO  QR detected: DEVICE-001
INFO  Digits detected: 1250
INFO  Confidence: 0.91
INFO  Recognition stabilized
INFO  Record saved: id=42
```

Errors:

```text
WARN  QR not detected
WARN  Digit confidence below threshold
ERROR Database write failed
```

For development, the system should also be able to save/debug:

- Input frames.
- Annotated frames.
- Detection results.
- Recognition results.

---

# 25. Performance Requirements

The first target is reliable recognition rather than maximum FPS.

Possible initial target:

```text
Camera:
    720p / 1080p

Inference:
    ~10–30 FPS depending on hardware

Recognition:
    stable result within a few frames

Database:
    local write after successful recognition
```

Actual performance should be measured on the deployment machine rather than assumed.

Important optimization areas:

- Resize frames efficiently.
- Avoid unnecessary image copies.
- Run QR and YOLO processing at appropriate intervals.
- Avoid running expensive inference on every frame if unnecessary.
- Reuse loaded models.
- Keep database writes asynchronous where appropriate.
- Avoid blocking the camera loop.

---

# 26. Processing Strategy

A possible runtime loop:

```text
while application_running:

    frame = camera.read()

    qr_result = qr_decoder.process(frame)

    if should_run_digit_detection():
        digit_result = digit_detector.process(frame)

    recognition = aggregator.combine(
        qr_result,
        digit_result
    )

    if recognition.is_valid():
        stabilizer.update(recognition)

    if stabilizer.is_stable():
        if not duplicate_detector.is_duplicate():
            database.save(recognition)

    ui.update(frame, recognition)
```

The important design principle is:

> Camera capture, recognition, validation, and persistence should be separate stages.

---

# 27. Project Phases

## Phase 1 — Camera

Goal:

```text
Camera → Live Frame
```

Tasks:

- Connect camera.
- Capture frames.
- Display frames.
- Measure FPS.
- Handle camera disconnects.

Deliverable:

```text
Stable local camera stream.
```

---

## Phase 2 — QR

Goal:

```text
Camera → QR → String
```

Tasks:

- Integrate QR decoder.
- Detect QR.
- Decode payload.
- Display decoded data.
- Test different QR sizes and angles.

Deliverable:

```text
Reliable QR recognition.
```

---

## Phase 3 — Seven-Segment Dataset

Goal:

```text
Dataset → Valid YOLO Dataset
```

Tasks:

- Validate class IDs.
- Validate bounding boxes.
- Inspect mislabeled samples.
- Train/validation split.
- Visualize annotations.
- Confirm classes 0–9.

Deliverable:

```text
Clean seven-segment digit dataset.
```

---

## Phase 4 — Train Digit Detector

Goal:

```text
Dataset → YOLO Model
```

Tasks:

- Train pretrained YOLO weights.
- Monitor training loss.
- Validate the model.
- Inspect precision/recall/mAP.
- Test on unseen images.
- Export the trained model.

Deliverable:

```text
Seven-segment digit detection model.
```

---

## Phase 5 — Local Digit Inference

Goal:

```text
Camera → YOLO → Digits
```

Tasks:

- Load exported model locally.
- Run inference.
- Draw bounding boxes.
- Extract class IDs.
- Extract confidence.
- Sort digits.
- Reconstruct numeric string.

Deliverable:

```text
Live seven-segment number recognition.
```

---

## Phase 6 — QR + Digits

Goal:

```text
Camera
  ↓
QR + Digit Detection
  ↓
Combined Result
```

Tasks:

- Run both recognition systems.
- Synchronize results.
- Associate QR with digit value.
- Implement validation.

Deliverable:

```text
Structured recognition result.
```

---

## Phase 7 — Stabilization

Goal:

```text
Unstable frame results
        ↓
Stable recognition
```

Tasks:

- Compare consecutive results.
- Require repeated recognition.
- Reject unstable values.
- Add confidence thresholds.

Deliverable:

```text
Reliable recognition event.
```

---

## Phase 8 — Database

Goal:

```text
Recognition → Database
```

Tasks:

- Create SQLite database.
- Create schema.
- Implement repository.
- Insert records.
- Query records.
- Prevent duplicates.

Deliverable:

```text
Persistent measurement history.
```

---

## Phase 9 — Local UI

Goal:

```text
Camera + Recognition + Database
                ↓
             UI
```

Tasks:

- Camera preview.
- Detection overlay.
- QR result.
- Numeric result.
- Confidence.
- Recognition state.
- Recent records.

Deliverable:

```text
Usable local application.
```

---

## Phase 10 — Production Hardening

Tasks:

- Camera reconnect.
- Application restart recovery.
- Database backup.
- Logging.
- Configuration.
- Error handling.
- Performance profiling.
- Model loading failure handling.
- Long-running stability testing.

Deliverable:

```text
Local application suitable for continuous operation.
```

---

# 28. Configuration

Runtime configuration should be externalized.

Example:

```yaml
camera:
  device_id: 0
  width: 1280
  height: 720
  fps: 30

detection:
  confidence_threshold: 0.70
  input_size: 640

recognition:
  stable_frames: 3
  duplicate_window_seconds: 5

database:
  path: "./data/app.db"
```

This avoids recompiling the application when deployment parameters change.

---

# 29. Security and Privacy

Because the system is local:

- Camera data should remain on the local machine unless explicitly exported.
- Database files should remain local.
- No external CV API should be required.
- Network access should not be required for normal recognition.
- Sensitive QR payloads should not be unnecessarily written to logs.
- Database backups should be controlled by the operator.

---

# 30. Testing Strategy

Testing should happen at multiple levels.

## Unit Tests

Test:

- Digit sorting.
- Number reconstruction.
- Confidence calculation.
- Decimal formatting.
- Duplicate detection.
- Validation rules.

Example:

```text
Input:
[(5, x=200), (1, x=100), (2, x=150)]

Expected:
"125"
```

## Integration Tests

Test:

```text
Camera frame
    ↓
QR decoder
    ↓
Digit detector
    ↓
Aggregator
    ↓
Database
```

## Dataset Tests

Test:

- All classes.
- Different digit sizes.
- Different backgrounds.
- Low-light images.
- Blur.
- Rotated displays.

## Long-Running Test

Run:

```text
Application
    ↓
Camera
    ↓
Recognition
    ↓
Database
```

for an extended period and monitor:

- Memory usage.
- CPU/GPU usage.
- FPS.
- Recognition failures.
- Database growth.
- Camera stability.

---

# 31. Important Engineering Principle

The system should not treat the ML model as the entire application.

The ML model is only one component:

```text
              ┌─────────────┐
              │    Camera   │
              └──────┬──────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
     QR Decoder            ML Detector
          │                     │
          └──────────┬──────────┘
                     ▼
               Post-processing
                     │
                     ▼
                Validation
                     │
                     ▼
                 Database
                     │
                     ▼
                    UI
```

The production reliability of the system depends heavily on:

- Data quality.
- Detection post-processing.
- Temporal stabilization.
- Validation.
- Duplicate handling.
- Camera handling.
- Database reliability.

Not only model accuracy.

---

# 32. Future Extensions

Once the basic system works, the architecture can support additional features.

## Multiple Display Types

Support different display configurations:

```text
7-segment
14-segment
LCD
LED
```

## Multiple Numeric Formats

Examples:

```text
12
12.5
12.50
001250
-12.50
```

## Multiple QR Codes

The system could associate multiple QR codes with different objects.

## Device Profiles

Example:

```text
DeviceProfile:
    device_id
    digit_count
    decimal_position
    expected_range
    recognition_threshold
```

Then:

```text
QR → Device Profile
        ↓
Expected numeric format
        ↓
Validation
```

## Industrial Integration

The application could eventually communicate with:

- PLCs.
- Industrial cameras.
- Serial devices.
- USB devices.
- Weighing scales.
- Conveyor controllers.
- MQTT.
- REST APIs.

---

# 33. Potential Final Architecture

A mature version could look like:

```text
                         ┌───────────────────┐
                         │      Camera       │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │  Frame Pipeline   │
                         └─────────┬─────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
             ┌─────────────┐              ┌──────────────┐
             │ QR Decoder  │              │ YOLO Detector│
             └──────┬──────┘              └──────┬───────┘
                    │                             │
                    ▼                             ▼
               QR Payload                    Digit Boxes
                                                  │
                                                  ▼
                                           Digit Processor
                                                  │
                                                  ▼
                                           Numeric Value
                    │                             │
                    └──────────────┬──────────────┘
                                   ▼
                         ┌───────────────────┐
                         │    Aggregator     │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │   Stabilization   │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │    Validation     │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │ Local Database    │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │   Local UI/API    │
                         └───────────────────┘
```

---

# 34. MVP Definition

The minimum viable product is complete when the following workflow works reliably:

```text
1. Start application.

2. Camera starts.

3. Object enters camera view.

4. QR code is detected.

5. QR payload is decoded.

6. Seven-segment digits are detected.

7. Digits are sorted from left to right.

8. Numeric value is reconstructed.

9. QR + numeric value are combined.

10. Result is validated.

11. Stable recognition is confirmed.

12. Record is written to SQLite.

13. UI shows the saved record.
```

Example final result:

```text
QR:
DEVICE-001

Detected:
1 2 5 0

Value:
12.50

Confidence:
91%

Status:
SAVED

Database:
measurement #42
```

That is the core product.

Everything else should be built around making this pipeline accurate, stable, and maintainable.
