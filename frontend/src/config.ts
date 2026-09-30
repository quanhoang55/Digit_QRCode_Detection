const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000'
export const config = { apiBaseUrl: apiBaseUrl.replace(/\/$/, ''), videoStreamUrl: import.meta.env.VITE_VIDEO_STREAM_URL ?? `${apiBaseUrl}/stream`, detectionWebSocketUrl: import.meta.env.VITE_DETECTION_WS_URL ?? 'ws://localhost:8000/ws/detections' }
