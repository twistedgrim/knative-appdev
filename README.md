# Knative Application Developer Platform

A Knative-based Application Developer Platform prototype that provides a developer workflow:
`upload code -> build image -> deploy service`.

## Goals
- Deliver a local Minikube MVP first.
- Provide repeatable setup scripts and manifests for Knative Serving.
- Implement source-to-image and upload-driven deployment flow incrementally.
- Keep docs aligned with implementation checkpoints.

## Project Structure
- `docs/` - architecture, local development, and deployment workflow docs.
- `manifests/` - Kubernetes/Knative manifests.
- `scripts/` - setup and verification scripts.
- `src/` - platform service code.
- `tests/` - local test helpers and integration checks.

## Quickstart
```bash
./scripts/setup-minikube.sh
./scripts/install-knative-serving.sh
./scripts/verify-knative.sh
kubectl apply -f manifests/build/runtime-config-example.yaml
APP_DIR=src/functions/hello-func ./scripts/func-build-deploy.sh

cd src/upload-api
MOCK_DEPLOY=true go run .
```

In another terminal:
```bash
./tests/test-upload-workflow.sh
```

For expected output details and troubleshooting, see `docs/local-dev.md`.

## Roadmap
See `PLAN.md` for phased implementation from local MVP to production-readiness.

## Validation
```bash
./tests/validate-local.sh
```


## Sample Upload Demo
```bash
./scripts/upload-sample-webapp.sh
```

Sample app source lives in `samples/webapp`.

## Localhost Access (Knative)
```bash
./scripts/expose-knative-localhost.sh
# new terminal:
./scripts/curl-knative-localhost.sh
```

## Task Runner
Use `go-task` shortcuts:
```bash
task cluster:up
task knative:install
task verify
```

Expose Knative on localhost (keep this running):
```bash
task expose:localhost
```

In a second terminal:
```bash
task curl:localhost
```

Background localhost exposure:
```bash
task expose:localhost:bg
task curl:localhost
task expose:localhost:stop
```

## One-Command Demo Flow
Run full local demo orchestration:
```bash
task flow:demo
```

This will:
- expose Knative service routing on localhost:8081
- start upload API in mock mode on localhost:8080
- upload `samples/webapp` bundle and poll deployment status

Stop background demo services:
```bash
task flow:demo:stop
```

## Demo Complete
Primary end-to-end demo entry point:
```bash
task flow:demo:real
```

This runs a real upload -> build -> deploy workflow and creates/updates:
- `sample-webapp` Knative Service in `default` namespace

Verify:
```bash
kubectl get ksvc sample-webapp -n default
```

Open in browser (with localhost exposure running):
- `http://sample-webapp.default.localhost:8081`

Real build/deploy demo (creates an actual Knative service for uploaded sample app):
```bash
task flow:demo:real
kubectl get ksvc sample-webapp -n default
```

Uploaded app URL after localhost exposure:
- `http://sample-webapp.default.localhost:8081`
