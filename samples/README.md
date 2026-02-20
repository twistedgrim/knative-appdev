# Samples Contract

This directory contains app bundles used to test upload/build/deploy flows.

## Required Structure
Each sample app must live in its own subdirectory:

- `samples/<app-name>/Dockerfile` (required)
- app source files and runtime assets

## Runtime Contract
- Container must start an HTTP server.
- App must listen on `PORT` (Knative runtime port).
- App should run as a single container process.

## Build/Deploy Contract
The upload/build flow uses:
- `scripts/upload-app.sh` (client upload/poll wrapper)
- `scripts/build-deploy-local.sh` (backend build/deploy path)

Current backend behavior expects:
- `Dockerfile` present at app root (`APP_DIR/Dockerfile`)
- build context is the app directory itself

## Add A New Sample
1. Create `samples/<app-name>/`.
2. Add `Dockerfile`.
3. Ensure app listens on `PORT` (fallback `8080` is fine).
4. Optionally add `README.md` in that sample directory.
5. Validate upload:

```bash
./scripts/upload-app.sh --app-dir samples/<app-name> --service <app-name> --namespace demo-apps
```

## Existing Samples
- `samples/webapp`
- `samples/go-webapp`
- `samples/ts-webapp`
- `samples/rust-webapp`
- `samples/python-webapp`
