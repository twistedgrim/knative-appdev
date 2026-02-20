# Plan

## Goal
Build a Knative-based Application Developer Platform demo with a source-code deployment workflow.

## Current Status
- [x] Phase 1 scaffold and core docs (`docs/`, `manifests/`, `scripts/`, `src/`, `tests/`)
- [x] Phase 2 local Knative baseline on Minikube (Serving + Kourier + sample service)
- [x] Phase 3 source-to-image and deployment path for demo uploads
- [x] Phase 4 upload workflow demo API with status endpoints and runnable demo flows

## Delivered Demo Capabilities
- Local Minikube + Knative setup scripts and verification scripts.
- Localhost routing for Knative services (`*.localhost` via Kourier port-forward helpers).
- Upload API accepting bundle uploads (`zip`/`tar`) with async status reporting.
- Sample frontend/backend webapp bundle for upload testing.
- One-command demo flows:
  - `task flow:demo` (mock deploy path)
  - `task flow:demo:real` (real image build + real Knative service deployment)

## Phase 1: Local MVP Foundation
- Install and validate Knative Serving on Minikube.
- Deploy sample Knative service and verify readiness/routing.
- Document local setup and expected outputs.

## Phase 2: Build + Deploy Path
- Support source bundle to container image build.
- Deploy/update Knative service from build output.
- Define image/tag conventions and runtime config handling.

## Phase 3: Upload Workflow
- Accept source bundles via API.
- Trigger build and deploy automatically.
- Expose deployment status, revision, and log hints.

## Phase 4: Demo Orchestration and UX
- Add reusable sample app for end-to-end demo.
- Add task-driven demo commands for repeatable local runs.
- Expose services on localhost for browser-based demo validation.

## Immediate Next Steps
1. Improve upload/build status granularity (streaming or step-level progress).
2. Add stronger bundle validation rules and clearer failure messages.
3. Add `Taskfile` targets for smoke checks of deployed uploaded apps.

## Out of Scope (Current)
- Production-readiness hardening (full observability stack, CI/release pipelines, backup/recovery runbooks).
