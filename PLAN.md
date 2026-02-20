# Plan

## Goal
Build a Knative-based Application Developer Platform demo with a source-code deployment workflow.

## Current Status
- [x] Phase 1 scaffold and core docs (`docs/`, `manifests/`, `scripts/`, `src/`, `tests/`)
- [x] Phase 2 local Knative baseline on Minikube (Serving + Kourier + sample service)
- [x] Phase 3 source-to-image and deployment path for demo uploads
- [x] Phase 4 upload workflow demo API with status endpoints and runnable demo flows
- [x] Demo UX hardening: consolidated exposure script, namespace cleanup model, dashboard revisions, one-command prep target

## Delivered Demo Capabilities
- Local Minikube + Knative setup scripts and verification scripts.
- Localhost routing for Knative services with both `:8081` and clean port-80 options (`minikube tunnel`, auto-fallback mode).
- Upload API accepting bundle uploads (`zip`/`tar`) with async status reporting.
- Sample frontend/backend webapp bundle for upload testing.
- Namespace split: demo workloads in `demo-apps`, platform workloads in `platform-system`.
- App dashboard service with revision visibility (latest created and latest ready revisions).
- Demo cleanup command that clears only demo workloads (`task demo:clean`).
- Unified localhost exposure script with mode/action flags (`scripts/expose-knative.sh`) and task wrappers.
- One-command demo flows:
  - `task flow:demo` (mock deploy path)
  - `task flow:demo:real` (real image build + real Knative service deployment)
  - `task demo:prep` (idempotent platform bring-up without demo apps)
  - `task demo:seed:apps` (explicit baseline app deployment after prep)

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
1. Stabilize `cluster:up` + Knative startup race handling to reduce transient webhook restart windows during rapid re-runs.
2. Add deployment history persistence (retain more than latest upload state, include timestamps and revision chain).
3. Add richer dashboard filters/sorting (namespace, readiness, service name) and quick links to logs/status endpoints.
4. Add smoke test automation that validates clean-namespace flow: `demo:clean -> flow:demo:real -> demo:upload:go -> demo:dashboard`.

## Out of Scope (Current)
- Production-readiness hardening (full observability stack, CI/release pipelines, backup/recovery runbooks).
