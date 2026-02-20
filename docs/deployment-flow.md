# Deployment Flow

## Target UX
An Application Developer Platform workflow:
1. Upload code bundle.
2. Platform builds an image.
3. Platform deploys/updates a Knative Service.
4. Platform returns deployment status and revision.

## Source-to-Image Choice (Phase 3)
The MVP uses a **local Minikube image build path** for source-to-image support.

### Why this path first
- Fastest way to prove source -> image -> Knative deploy in local Minikube.
- Avoids external registry requirements for local demos.
- Keeps deploy behavior explicit (`minikube image build` + Knative Service apply).

## Image Naming and Tagging Convention
Image format:
`<registry>/<repo>/<service-name>:<tag>`

Default values in `scripts/build-deploy-local.sh`:
- image: `dev.local/<service-name>:<deployment-id-or-timestamp>`
- service-name: from upload request (`service`) or script env var
- namespace: from upload request (`namespace`) or script env var

Example image:
`dev.local/sample-webapp:dep-000001`

## Runtime Configuration Handling
- Runtime settings are carried via environment variables and Knative Service spec.
- Base runtime values can live in ConfigMaps and be wired into service templates.
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
  -F "namespace=demo-apps"
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
Sample requirements for adding new apps are documented in `samples/README.md`.

Wrapper script:
```bash
./scripts/upload-app.sh --app-dir samples/webapp --service sample-webapp --namespace demo-apps
./scripts/upload-sample-webapp.sh
```

Optional overrides:
```bash
API_URL=http://localhost:8080 \
SERVICE_NAME=sample-webapp \
NAMESPACE=demo-apps \
./scripts/upload-sample-webapp.sh
```

Client responsibility:
- bundle source and call Upload API
- poll deployment status endpoints

Backend responsibility:
- validate bundle contents and constraints
- build container image and update Knative Service
- access Kubernetes/Knative APIs and return status/revision/log hints

If the upload API runs in mock mode (`MOCK_DEPLOY=true`), this flow still validates bundle upload, extraction, and status transitions.

## One-Command Demo
```bash
task flow:demo
```

Cleanup:
```bash
task flow:demo:stop
```

## Full Demo Prep
For a single command that brings up the platform stack (without deploying demo apps):
```bash
task demo:prep
```
This command is idempotent and is intended for live-demo preparation.

To deploy baseline demo applications after prep:
```bash
task demo:seed:apps
```

## Real Build/Deploy Demo
Use this to create a real Knative service from the uploaded sample bundle:
```bash
task flow:demo:real
```

Verification:
```bash
kubectl get ksvc sample-webapp -n demo-apps
kubectl get revision -n demo-apps -l serving.knative.dev/service=sample-webapp
curl http://sample-webapp.demo-apps.localhost:8081
```

## Application Dashboard
A simple dashboard service is available at `src/app-dashboard`.

Deploy:
```bash
task demo:dashboard
```

It shows Knative services currently built/running by querying Kubernetes API for `services.serving.knative.dev`.
