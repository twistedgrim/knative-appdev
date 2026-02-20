# Architecture

## Objective
Build a Knative-based Application Developer Platform that provides a workflow for:
1. Upload source code.
2. Build a container image.
3. Deploy to Knative Serving.

## POC Scope (Local)
The first target is a local Minikube environment with Knative Serving and a minimal source-upload API for demo/testing.

### Core Components
- **Minikube cluster**: local Kubernetes runtime.
- **Knative Serving**: deployment, revisioning, autoscaling, and traffic routing.
- **Build path**: source-to-image implementation (selected in later phase).
- **Upload API service**: accepts source bundles and triggers build + deploy.
- **Platform docs/scripts**: reproducible setup and verification.

## High-Level Flow
1. Developer uploads a `zip` or `tar` bundle to platform API.
2. Platform validates bundle metadata and extracts source.
3. Platform triggers source-to-image build pipeline.
4. Built image is deployed/updated as a Knative Service.
5. Platform exposes status: latest revision, rollout state, and log pointers.

## Design Principles
- Prefer small, reversible, scriptable changes.
- Keep local-first workflow explicit and reproducible.
- Keep manifests and docs aligned to each incremental capability.
- Avoid plaintext secrets; use Kubernetes secret patterns.
- Keep scope focused on POC/demos, not production hardening.

## Future Expansion
- Multi-template app catalog.
- Rollbacks and traffic splitting controls.
- Policy and quota guardrails.
- CI/CD and production-grade observability.
