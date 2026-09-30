# BACKEND — Local QR + Seven-Segment Capture Service

## 1. Goal

Build one local FastAPI process that:

1. Captures frames from a USB webcam or a network/wireless camera.
2. Decodes QR data and detects seven-segment digits.
3. Stabilizes and validates one recognition result.
4. Streams video and sends lightweight detection metadata to the frontend.
5. Saves operator-approved measurements locally in one durable file.

`docs/ENDPOINT.md` is the authoritative HTTP and WebSocket contract. This document defines the internal backend design required to implement it efficiently.

## 2. Key Decisions

| Concern | Decision | Reason |
| --- | --- | --- |
| API | FastAPI + Pydantic | Already selected; supports REST, lifespan management, and WebSockets. |
| Camera | One shared OpenCV capture service | Prevents competing camera handles and repeated device initialization. |
| USB camera | OpenCV device index, such as `0` | Works with standard USB/UVC webcams. |
| Wireless camera | OpenCV stream URL, normally RTSP | Supports IP cameras without changing recognition logic. |
| Recognition updates | WebSocket JSON | Small, timely messages; ideal for boxes and status. |
| MVP video | MJPEG `GET /stream` | Works with the existing React `<img>` frontend and is simple locally. |
| Low-latency video upgrade | WebRTC | More efficient than MJPEG or WebSocket video for sustained real-time video. |
| Persistence | Optional SQLite in one `.db` file | Local, transactional, queryable, and built into Python when enabled. |
| CSV/TXT | Export only, not the source of truth | Plain-text appends are fragile for concurrent writes, duplicates, recovery, and queries. |

## 3. Camera Design — USB and Wireless

The backend must support a single `CAMERA_SOURCE` setting rather than assuming a USB-only device.

```text
CAMERA_SOURCE=0
```

opens the first USB webcam. On Linux this normally maps to `/dev/video0`; OpenCV should receive the numeric index, not the literal device path unless the selected OpenCV backend requires it.

```text
CAMERA_SOURCE=rtsp://user:password@192.168.1.50:554/stream1
```

opens a wireless/IP camera. HTTP MJPEG camera URLs are also valid when OpenCV can decode them.

### Required camera settings

| Setting | Default | Notes |
| --- | --- | --- |
| `CAMERA_SOURCE` | `0` | Integer-like values mean USB index; other values are stream URLs. |
| `CAMERA_BACKEND` | platform default | Optional override, e.g. `CAP_AVFOUNDATION`, `CAP_DSHOW`, or `CAP_FFMPEG`. |
| `FRAME_WIDTH` | `1280` | Requested capture width; actual size must be read back from the device. |
| `FRAME_HEIGHT` | `720` | Requested capture height. |
| `CAMERA_FPS` | `30` | Requested capture rate; hardware may return a different rate. |
| `CAMERA_RECONNECT_SECONDS` | `2` | Delay before reopening a failed camera source. |
| `RTSP_TRANSPORT` | `tcp` | Prefer TCP for reliable Wi-Fi streams; make configurable. |

### Capture lifecycle

```text
FastAPI startup
  → open camera once
  → apply requested width, height, and FPS
  → start one capture worker
  → publish the newest successful frame

Camera read failure
  → mark camera unavailable
  → publish an error/status event
  → release camera handle
  → retry open after configured delay

FastAPI shutdown
  → stop workers
  → release camera handle
  → close database
```

Do not open `cv2.VideoCapture` inside a route, WebSocket connection, JPEG generator, or inference call. This is essential for USB camera stability and prevents a wireless stream from being opened multiple times.

## 4. High-Performance Video and Metadata Transport

### Do not send continuous video over WebSocket

WebSocket can carry binary image bytes, but it is not the preferred video transport here. It requires the application to implement encoding cadence, backpressure, frame dropping, client buffering, and reconnection behavior that browser video protocols already solve. It also makes it easy for slow clients to consume backend memory.

Keep WebSocket for recognition JSON only:

```text
WebSocket /ws/detections
  → boxes, QR payload, digits, confidence, status, frame dimensions
```

### MVP: MJPEG

Implement the contract endpoint:

```text
GET /stream
Content-Type: multipart/x-mixed-replace; boundary=frame
```

The JPEG generator reads the newest captured frame; it must never request a new camera read. Use a moderate JPEG quality setting (default `80`) and only encode when a connected stream client needs the next frame. Each stream client must see a current frame rather than a backlog of old frames.

MJPEG is appropriate for the first local station because it is easy to debug and works with the already-built frontend. Expect higher bandwidth and CPU cost than a video codec.

### Recommended upgrade: WebRTC

For a production-like, low-latency local video experience, add WebRTC after the MJPEG MVP is stable.

```text
Camera capture worker
  → latest-frame buffer
  → custom WebRTC video track
  → browser RTCPeerConnection

FastAPI signaling endpoint
  ↔ SDP offer/answer
```

Use `aiortc` for the Python WebRTC peer connection. Add a signaling endpoint such as `POST /webrtc/offer` only when the React frontend is updated to use `RTCPeerConnection`. Do not remove `/stream`; retain it as the development, diagnostic, and fallback transport.

WebRTC benefits:

- H.264/VP8 encoding rather than repeated JPEG images.
- Lower latency and bandwidth for a continuous camera view.
- Built-in frame pacing and adaptation for a wireless browser client.
- A clean separation between video media and WebSocket recognition metadata.

## 5. Processing Pipeline

The capture loop and inference loop must be independent. A slow model must not freeze the live camera view.

```text
USB / RTSP camera
       │
       ▼
Capture worker (target: 30 FPS)
       │ latest frame only; overwrite older frame
       ├──────────────► MJPEG / future WebRTC video
       │
       ▼
Inference worker (target: configurable 5–10 FPS)
       ├── QR decoder
       ├── YOLO digit detector
       ├── NMS and class validation
       ├── sort digits by horizontal center
       ├── format value
       ├── confidence + temporal stabilization
       └── atomic recognition snapshot
                         │
                         └──► WebSocket broadcaster
```

### Frame and queue policy

- Store the latest raw frame plus a monotonically increasing `frame_id` and capture timestamp under a lock.
- The inference worker takes the newest frame available. It must drop intermediate frames instead of building an unbounded queue.
- Use a separate worker thread/process for OpenCV, QR decoding, and YOLO work; do not run blocking CV operations on FastAPI's async event loop.
- Keep the most recent validated `RecognitionSnapshot` in memory. `POST /measurements` validates against this snapshot.
- Publish `storage_enabled` in recognition events so the frontend can disable Save while `STORAGE_ENABLE=false`.
- Encode stream JPEG copies after capture. Never modify the shared raw frame with overlay drawings.

### Recognition rules

- Accept `model_1` (classes `0`–`9` are digits, optional `10` is `none`) and `model_2` (`0='-'`, `1='.'`, `2`–`11` are digits `0`–`9`). Select the mapping from checkpoint class names; reject other mappings.
- Sort digit detections by bounding-box horizontal center.
- Aggregate confidence as the minimum digit confidence for the MVP.
- Use `DECIMAL_PLACES` as the implied decimal separator for both model versions; ignore `model_2`'s dot class, but preserve a valid leading minus sign. For two decimal places, `040` means `0.40`, `643` means `6.43`, and `1300` means `13.00`.
- Require the same `(qr_data, raw_digits)` result for `REQUIRED_STABLE_FRAMES` consecutive inference frames before emitting `READY_TO_SAVE`.
- Emit `null` values for missing QR/digit results. Never reuse a result from a prior object.

## 6. Internal Package Layout

```text
backend/src/backend/
├── main.py                 # FastAPI application factory and lifespan
├── config.py               # Pydantic settings / environment parsing
├── api/
│   ├── routes_health.py
│   ├── routes_stream.py
│   ├── routes_measurements.py
│   ├── routes_websocket.py
│   └── schemas.py           # API-only Pydantic models from ENDPOINT.md
├── camera/
│   ├── source.py            # USB index or URL parsing and OpenCV open logic
│   └── capture_service.py   # one shared capture worker and latest-frame access
├── cv/
│   ├── qr_decoder.py
│   ├── digit_detector.py    # one loaded YOLO model
│   └── types.py
├── recognition/
│   ├── processor.py         # QR + digit aggregation
│   ├── stabilizer.py
│   └── snapshot.py
├── services/
│   ├── processing_service.py
│   ├── measurement_service.py
│   └── websocket_manager.py
├── storage/
│   ├── sqlite_repository.py
│   ├── schema.sql
│   └── csv_exporter.py      # optional explicit export only
└── tests/
```

Route handlers only parse input, invoke a service, and serialize a response. They must not contain OpenCV/YOLO calls or raw SQL.

## 7. Local Storage Design

### Use SQLite as the primary local file

When `STORAGE_ENABLE=true`, use the Python standard-library `sqlite3` module. The database is one portable file, for example:

```text
backend/data/measurements.db
```

SQLite is still a local-file solution, but it adds atomic transactions, unique/duplicate checks, stable IDs, timestamps, sorting, and safe reads while the frontend is active. It does not require Supabase, MongoDB, Docker, or a database server.

With `STORAGE_ENABLE=false`, do not initialize SQLite or create the file. `GET /measurements` returns an empty array and `POST /measurements` returns `503 STORAGE_DISABLED`. QR and digit recognition continue to appear in the frontend.

```sql
CREATE TABLE IF NOT EXISTS measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    qr_data TEXT NOT NULL,
    raw_digits TEXT NOT NULL,
    numeric_value REAL NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    captured_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_measurements_created_at
    ON measurements (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_measurements_duplicate_lookup
    ON measurements (qr_data, numeric_value, created_at DESC);
```

Enable SQLite WAL mode and a busy timeout at startup so one save does not block recent-record reads:

```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

### CSV export

Provide CSV only as an explicit export operation, such as a CLI command or future `GET /measurements/export.csv`. Generate it by querying SQLite, writing a temporary file, then atomically replacing the final export file. Do not append to a CSV from camera/inference threads.

This gives the user a simple spreadsheet-compatible file without giving up reliable persistence.

## 8. FastAPI Lifespan and Concurrency

At startup:

1. Load settings.
2. When storage is enabled, create `data/`, initialize SQLite schema, and verify the connection.
3. Load trained digit weights from `backend/model/best.pt` by default. If absent, report model unavailability while camera and QR continue operating.
4. Start the shared camera capture service.
5. Start the processing service and WebSocket manager.

At shutdown, cancel workers in reverse order, release `VideoCapture`, close WebSocket clients, then close SQLite connections.

Use bounded, latest-value communication between workers. Never let the number of frames, JPEGs, or recognition events grow without a limit.

## 9. Dependencies

Required additions to the backend environment:

```text
opencv-python       camera capture, JPEG encoding, QR decoding
ultralytics         YOLO model inference
numpy               image arrays
```

Already present:

```text
fastapi
pydantic
uvicorn
```

Optional only for the WebRTC phase:

```text
aiortc
av
```

Do not add Supabase, MongoDB, an ORM, or a queue broker for the local MVP.

## 10. Reliability, Security, and Observability

- Bind to `127.0.0.1` by default. Exposing the service to the LAN requires deliberate configuration.
- Restrict CORS to configured development origins; do not use `*` with credentials.
- Do not log QR payloads or RTSP credentials at info level. Redact camera URLs in errors.
- Return the error shape and statuses defined in `ENDPOINT.md`; never expose stack traces to the frontend.
- Log camera connect/disconnect/reconnect, model load, inference duration, recognition status transitions, save outcomes, and database failures.
- Track capture FPS, inference FPS, latest-frame age, processing duration, active WebSocket count, and MJPEG client count for diagnostics.

## 11. Delivery Sequence

1. Implement configuration, SQLite repository, health route, and application lifespan.
2. Implement shared USB camera capture, reconnection, and MJPEG `GET /stream`.
3. Add QR decoding and typed WebSocket snapshots using fixed/test detector output.
4. Integrate the validated digit model and recognition/stabilization logic.
5. Implement `GET`/`POST /measurements`, duplicate prevention, and frontend integration.
6. Test a USB webcam and a real RTSP wireless camera under disconnect/reconnect conditions.
7. Measure MJPEG latency/FPS; add WebRTC only if it is insufficient for the deployment station.

## 12. Acceptance Criteria

- The system works with a USB webcam through `CAMERA_SOURCE=0` and a wireless camera through an RTSP URL.
- Only one camera connection exists regardless of stream viewers or WebSocket clients.
- Camera streaming continues while inference is slow; inference uses the latest frame rather than accumulating delay.
- `/stream`, `/ws/detections`, and every REST endpoint comply with `ENDPOINT.md`.
- A valid stable recognition can be saved once and appears in recent records after restart because it is stored in SQLite.
- A failed camera, model, or database is reported without crashing the process.
- CSV export is possible without using CSV as the live transactional data store.
- WebRTC remains an optional upgrade path and does not change recognition metadata or persistence behavior.
