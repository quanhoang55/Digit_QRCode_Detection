# ENDPOINT — Local Capture Backend Contract

## 1. Purpose and Scope

This document is the implementation contract for the local FastAPI backend used by the React frontend.

The backend owns camera capture, QR decoding, seven-segment inference, recognition validation, and persistence. The frontend only renders the stream and metadata, then explicitly requests a save.

The first release exposes:

```text
GET        /health
GET        /stream
GET        /measurements
POST       /measurements
WebSocket  /ws/detections
```

All REST responses use JSON except `GET /stream`. REST field names are `snake_case`. Timestamps are ISO 8601 UTC strings except WebSocket event `timestamp`, which is epoch milliseconds.

## 2. Runtime Configuration

Default local backend address:

```text
http://localhost:8000
```

The backend must make these settings configurable through environment variables or one configuration module:

| Setting | Default | Purpose |
| --- | --- | --- |
| `HOST` | `127.0.0.1` | Bind only to the local machine by default. |
| `PORT` | `8000` | HTTP and WebSocket port. |
| `CAMERA_INDEX` | `0` | OpenCV camera index. |
| `FRAME_WIDTH` | `1280` | Requested camera width. |
| `FRAME_HEIGHT` | `720` | Requested camera height. |
| `DETECTION_CONFIDENCE` | `0.25` | Candidate digit boxes returned by YOLO. |
| `INFERENCE_CONFIDENCE` | `0.70` | Minimum digit confidence accepted by recognition. |
| `MODEL_PATH` | `backend/model/best.pt` | Path to trained digit weights; QR/camera service can start before this file exists. |
| `DATABASE_PATH` | `backend/data/measurements.db` | Local SQLite database path, resolved from repository root. |
| `CSV_PATH` | `backend/data/measurements.csv` | Local CSV path, resolved from repository root. |
| `STORAGE_TYPE` | `sqlite` | Primary local store: `sqlite` or `csv`. |
| `STORAGE_ENABLE` | `false` | Create/use the selected local store only when enabled. |
| `CORS_ORIGINS` | `http://localhost:5173` | Comma-separated development origins. |

The frontend supports matching Vite variables:

```text
VITE_API_BASE_URL=http://localhost:8000
VITE_VIDEO_STREAM_URL=http://localhost:8000/stream
VITE_DETECTION_WS_URL=ws://localhost:8000/ws/detections
```

## 3. Shared Models

### Recognition status

The backend must use exactly one of these values:

```text
WAITING
DETECTING
READY_TO_SAVE
SAVED
LOW_CONFIDENCE
INCOMPLETE
ERROR
```

`READY_TO_SAVE` means all of these are true: a QR payload exists, a valid ordered reading exists, a numeric value exists, confidence meets the configured threshold, and the result passes backend validation. A misplaced minus sign is `INCOMPLETE` and cannot be saved. The `model_2` dot class is ignored.

### Detection object

Bounding-box coordinates are pixels in the original camera frame, with origin at the top-left. `width` and `height` must be positive.

```json
{
  "type": "digit",
  "class": 5,
  "value": 5,
  "confidence": 0.94,
  "bbox": {
    "x": 420,
    "y": 192,
    "width": 51,
    "height": 110
  }
}
```

Valid types are `digit`, `qr`, and `display`. The frontend hides the `display` ROI overlay but still receives its metadata.

- For `model_1`, a digit has class ID and value in the range `0`–`9`.
- For `model_2`, `class` is the checkpoint ID (`0` is `-`, `2`–`11` are digits `0`–`9`) and `value` is the corresponding symbol string. Class `1` (`.`) is ignored and not emitted.
- A QR detection may omit `class` and `value`.
- `confidence` is a number from `0` to `1`.

### Recognition event

```json
{
  "type": "recognition",
  "timestamp": 1790676000000,
  "frame_width": 1280,
  "frame_height": 720,
  "detections": [
    {
      "type": "qr",
      "confidence": 1.0,
      "bbox": { "x": 90, "y": 180, "width": 150, "height": 150 }
    },
    {
      "type": "digit",
      "class": 1,
      "value": 1,
      "confidence": 0.98,
      "bbox": { "x": 420, "y": 192, "width": 51, "height": 110 }
    }
  ],
  "qr": { "data": "DEVICE-001" },
  "raw_digits": "1250",
  "numeric_value": 12.5,
  "confidence": 0.91,
  "status": "READY_TO_SAVE",
  "storage_enabled": false
}
```

Nullable recognition fields must be explicitly `null` when unavailable; do not send stale QR or numeric values from an earlier frame.

```json
{
  "type": "recognition",
  "timestamp": 1790676000300,
  "frame_width": 1280,
  "frame_height": 720,
  "detections": [],
  "qr": null,
  "raw_digits": null,
  "numeric_value": null,
  "confidence": null,
  "status": "WAITING",
  "storage_enabled": false
}
```

`storage_enabled` tells the frontend whether to enable Save. A ready recognition may still be displayed while storage is disabled.

## 4. REST Endpoints

### `GET /health`

Returns process readiness. It must not attempt a database write or trigger inference.

**200 response**

```json
{
  "status": "ok",
  "camera": "connected",
  "model": "loaded",
  "database": "disabled",
  "storage_enabled": false
}
```

When storage is disabled, `database` is `disabled` and this alone does not make the service unhealthy. If camera or model is unavailable, or enabled storage fails, return `503` with the standard error response. The service may still stream camera and decode QR while digit weights are missing.

### `GET /stream`

Provides the current camera frames as an MJPEG stream.

**Response**

```text
200 OK
Content-Type: multipart/x-mixed-replace; boundary=frame
Cache-Control: no-store, no-cache, must-revalidate
```

Each part contains a JPEG encoded from the same raw camera frame used by the CV pipeline. The stream must not embed drawn detection boxes; the frontend draws metadata overlays independently.

If the camera cannot be opened or later fails, close the stream and log the cause. `GET /health` and the WebSocket must reflect the camera problem.

### `GET /measurements`

Returns the most recently saved records, newest first.

**Query parameters**

| Parameter | Default | Constraint |
| --- | --- | --- |
| `limit` | `20` | Integer from `1` to `100`. |

**200 response** — always a JSON array, including when empty. With storage disabled, return `[]`.

```json
[
  {
    "id": 42,
    "qr_data": "DEVICE-001",
    "raw_digits": "1250",
    "numeric_value": 12.5,
    "confidence": 0.91,
    "captured_at": "2026-09-29T12:01:20Z",
    "created_at": "2026-09-29T12:01:22Z"
  }
]
```

### `POST /measurements`

Persists an operator-approved recognition. The frontend only enables this action for a ready result, but the backend must repeat all validation.

**Request**

```json
{
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.5,
  "confidence": 0.91
}
```

**Validation requirements**

- `qr_data`: non-empty trimmed string.
- `raw_digits`: ASCII digits with an optional leading `-` for `model_2`. Both model versions use the configured implied decimal places; no dot is required or accepted in this field.
- `numeric_value`: finite number, including negative readings from `model_2`.
- `confidence`: finite number from `0` to `1`; the backend's current recognition confidence must meet `INFERENCE_CONFIDENCE`.
- The QR data, raw digits, and numeric value must match the latest validated recognition for the active camera frame. Use the backend's current confidence for the stored record; the browser confidence can differ slightly between frames.
- Reject an exact `(qr_data, numeric_value)` duplicate inside the configured duplicate window.

**201 response**

Returns the saved record using the same schema as `GET /measurements`.

```json
{
  "id": 42,
  "qr_data": "DEVICE-001",
  "raw_digits": "1250",
  "numeric_value": 12.5,
  "confidence": 0.91,
  "captured_at": "2026-09-29T12:01:20Z",
  "created_at": "2026-09-29T12:01:22Z"
}
```

After a successful save, publish a new recognition WebSocket event with `status: "SAVED"`. On the next distinct camera recognition, emit its actual new status rather than continuing to report `SAVED`.

With `STORAGE_ENABLE=false`, return `503` with code `STORAGE_DISABLED`; do not create a storage file. The frontend disables Save when the WebSocket event has `storage_enabled: false`. With `STORAGE_TYPE=csv`, a successful save atomically updates `CSV_PATH` with the same fields returned by this endpoint.

## 5. WebSocket Endpoint

### `WebSocket /ws/detections`

The endpoint is server-to-client for the MVP. The client sends no required messages.

On connection, send the current recognition event immediately, then publish subsequent events whenever the CV pipeline has a new processed frame or recognition-state change. A target of 5–10 events per second is adequate; do not flood clients with every raw camera frame.

The backend must support multiple connected browser clients. A slow or disconnected client must not block camera capture, inference, database writes, or other clients.

Optional status/error event:

```json
{
  "type": "error",
  "timestamp": 1790676000000,
  "code": "CAMERA_UNAVAILABLE",
  "message": "Could not read a frame from camera 0"
}
```

For compatibility with the current frontend, normal recognition events must retain the exact `recognition` object shape in section 3.

## 6. Error Contract

Use standard HTTP status codes and this JSON body for all REST errors:

```json
{
  "detail": {
    "code": "DUPLICATE_RECORD",
    "message": "This QR and value were already saved recently."
  }
}
```

| Status | Error code examples | Meaning |
| --- | --- | --- |
| `400` | `INVALID_VALUE`, `INCOMPLETE_RECOGNITION` | Payload or active recognition is invalid. |
| `404` | `RECORD_NOT_FOUND` | Reserved for future item endpoints. |
| `409` | `DUPLICATE_RECORD` | Duplicate-prevention policy rejected the save. |
| `422` | FastAPI validation error | Request body or query parameter has the wrong type/shape. |
| `503` | `CAMERA_UNAVAILABLE`, `MODEL_UNAVAILABLE`, `DATABASE_UNAVAILABLE`, `STORAGE_DISABLED` | Required local dependency is unavailable or saving is disabled. |
| `500` | `INTERNAL_ERROR` | Unexpected server failure; never expose stack traces. |

## 7. Backend Implementation Boundaries

Organize the FastAPI application so routes remain thin:

```text
api/            FastAPI routes, Pydantic request/response schemas, WebSocket manager
camera/         Single shared camera capture service and JPEG encoding
qr/             QR location and decoding service
digit_detection/ model loading and raw YOLO inference
recognition/    ordering, decimal formatting, confidence, state, stabilization
database/       SQLite connection, schema, measurement repository
services/       orchestration: frame processing, persistence, duplicate prevention
```

Requirements:

- Open one shared camera during application lifespan; never open the camera once per HTTP/WebSocket request.
- Load trained digit weights once during application lifespan when available; keep camera/QR operation alive while weights are absent.
- Run QR decoding and digit inference off the async event loop if they block.
- Keep raw camera frames, model output, recognition aggregation, and database persistence independently testable.
- Configure CORS for the Vite local origin during development; do not use unrestricted origins by default.
- Store `captured_at` when the recognition was produced and `created_at` when persistence succeeds.

## 8. Acceptance Checklist

- `GET /health` reports camera, model, and database readiness.
- A browser can render `GET /stream` as an `<img>` MJPEG source.
- A browser receives a valid recognition event after opening `/ws/detections`.
- Detection boxes align with the stream using `frame_width` and `frame_height`.
- Missing QR or digit data is represented with `null`, not stale data.
- `POST /measurements` returns `201`; the returned record immediately appears in `GET /measurements`.
- Invalid, low-confidence, and duplicate saves return the defined error shapes and do not create records.
- Camera, model, and database failures are visible through `/health`, WebSocket status/error events, and server logs.
