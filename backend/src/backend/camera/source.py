"""Camera source parsing and OpenCV backend selection."""

import cv2


def parse_source(value: str) -> int | str:
    value = value.strip()
    if not value:
        raise ValueError("CAMERA_SOURCE must not be empty")
    return int(value) if value.isdecimal() else value


def backend_id(name: str | None) -> int:
    if not name:
        return cv2.CAP_ANY
    candidate = name.upper()
    if not candidate.startswith("CAP_"):
        candidate = "CAP_" + candidate
    result = getattr(cv2, candidate, None)
    if not isinstance(result, int):
        raise ValueError(f"Unsupported CAMERA_BACKEND: {name}")
    return result
