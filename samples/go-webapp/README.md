# go-webapp

Simple Go sample app for upload/build/deploy testing.

## Local run
```bash
cd samples/go-webapp
go run .
```

Open [http://localhost:8080](http://localhost:8080).

## Upload via existing wrapper
From repo root:
```bash
SAMPLE_DIR=samples/go-webapp SERVICE_NAME=go-webapp ./scripts/upload-sample-webapp.sh
```

Then open:
- `http://go-webapp.demo-apps.localhost:8081`
