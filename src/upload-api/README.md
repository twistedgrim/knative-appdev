# Upload API (Prototype)

Minimal API service for source bundle upload and asynchronous build/deploy trigger.

## Run locally
```bash
cd src/upload-api
MOCK_DEPLOY=true go run .
```

## Endpoints
- `GET /healthz`
- `POST /deploy` (multipart form field: `bundle`, optional `service`, `namespace`)
- `GET /status/latest`
- `GET /status/{id}`
