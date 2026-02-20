# AGENTS.md

Guidelines for AI agents working in this repository.

## Scope
- Keep this repo focused on a Knative-based application/developer platform.
- Current target is a local/demo platform (Minikube-first), not production hardening.
- Prefer small, reversible changes with clear validation steps.

## Workflow
1. Create a feature branch before making code changes.
2. Make focused commits with conventional commit messages.
3. Open a PR for review; do not merge directly to `master`/`main`.
4. Prefer staged demo setup: `task demo:prep` (platform only) then `task demo:seed:apps` (deploy baseline demo apps).

## Implementation Rules
- Follow existing structure and naming conventions.
- Keep docs and manifests in sync for each feature.
- Do not commit plaintext secrets; use secret-management patterns.
- Use the unified exposure entrypoint `scripts/expose-knative.sh` (do not introduce new parallel expose scripts).

## Verification
- Validate YAML/manifests before committing.
- Test changes locally (Minikube) where applicable.
- Prefer running `./tests/validate-local.sh` and task-based demo checks (`task flow:demo`, `task flow:demo:real`) for verification.
- For demo readiness, run `task demo:prep` and confirm platform services are ready, then run `task demo:seed:apps` to deploy baseline demo apps.
- For localhost routing changes, verify both `task expose:localhost:auto` and explicit mode checks via `scripts/expose-knative.sh --mode ... --status`.
- Include verification commands and outcomes in PR notes.

## Documentation
- Update `PLAN.md` when priorities or milestones change.
- Add usage docs for any new scripts, components, or workflows.
- Keep demo flow docs current (`README.md`, `docs/local-dev.md`, `docs/deployment-flow.md`) when commands or endpoints change.
