# Deployment Flow

## Target UX
An Application Developer Platform workflow:
1. Upload code bundle.
2. Platform builds an image.
3. Platform deploys/updates a Knative Service.
4. Platform returns deployment status and revision.

## Source-to-Image Choice (Phase 3)
The MVP uses **Knative Functions (`func`)** for initial source-to-image support.

### Why this path first
- Fastest way to prove source -> image -> Knative deploy in local Minikube.
- Fewer moving parts than a full in-cluster build controller for the first iteration.
- Direct alignment with Knative Serving primitives and developer workflow.

## Image Naming and Tagging Convention
Image format:
`<registry>/<repo>/<service-name>:<tag>`

Default values in `scripts/func-build-deploy.sh`:
- `registry`: `ghcr.io/${USER}`
- `repo`: `knative-appdev`
- `service-name`: `hello-func` (overridable)
- `tag`: short git SHA (`git rev-parse --short HEAD`) or timestamp fallback

Example image:
`ghcr.io/alice/knative-appdev/hello-func:a1b2c3d`

## Runtime Configuration Handling
- Runtime settings are carried via environment variables.
- Base runtime values can live in a ConfigMap, e.g. `manifests/build/runtime-config-example.yaml`.
- Sensitive values must be provided through Kubernetes Secrets (never committed as plaintext).

## Upload Workflow Prototype API (Phase 4)
Service location: `src/upload-api`.

### Endpoints
- `POST /deploy`: accepts `multipart/form-data` with `bundle` file and optional `service`, `namespace`.
- `GET /status/latest`: latest deployment state.
- `GET /status/{id}`: deployment state for an upload request.
- `GET /healthz`: readiness check.

### Status lifecycle
- `PENDING_UPLOAD_VALIDATION`
- `BUILD_IN_PROGRESS`
- `DEPLOY_IN_PROGRESS`
- `READY`
- `FAILED`

### Logs and revision info
Status responses include:
- `revision`: last known Knative revision (when available)
- `logsHint`: a kubectl command to fetch service logs

## Local API Example
Run API in mock mode:
```bash
cd src/upload-api
MOCK_DEPLOY=true go run .
```

Upload bundle:
```bash
curl -X POST http://localhost:8080/deploy \
  -F "bundle=@/path/to/source.tar.gz" \
  -F "service=my-uploaded-app" \
  -F "namespace=default"
```

Check latest status:
```bash
curl http://localhost:8080/status/latest
```

Check specific deployment:
```bash
curl http://localhost:8080/status/dep-000001
```

Run local smoke test:
```bash
./tests/test-upload-workflow.sh
```

## Sample App Upload
A simple upload target is available at `samples/webapp`.

Wrapper script:
```bash
./scripts/upload-sample-webapp.sh
```

Optional overrides:
```bash
API_URL=http://localhost:8080 \
SERVICE_NAME=sample-webapp \
NAMESPACE=default \
./scripts/upload-sample-webapp.sh
```

If the upload API runs in mock mode (`MOCK_DEPLOY=true`), this flow still validates bundle upload, extraction, and status transitions.

## One-Command Demo
```bash
task flow:demo
```

Cleanup:
```bash
task flow:demo:stop
```

## Real Build/Deploy Demo
Use this to create a real Knative service from the uploaded sample bundle:
```bash
task flow:demo:real
```

Verification:
```bash
kubectl get ksvc sample-webapp -n default
kubectl get revision -n default -l serving.knative.dev/service=sample-webapp
curl http://sample-webapp.default.localhost:8081
```
