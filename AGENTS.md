# Repository Guidelines

## Project Structure & Module Organization
- `cluster/` — Kubernetes manifests (e.g., `cluster-issuer.yaml`). Prefer one resource per file; use kebab-case filenames.
- As the tree grows, group by component: e.g., `cluster/cert-manager/issuer.yaml`, `cluster/ingress/web-ingress.yaml`.
- `.idea/` and `*.iml` — IDE metadata; not part of build/deploy.

## Build, Test, and Development Commands
- Validate manifests locally: `kubectl apply --dry-run=client -f cluster/` — checks syntax without changing the cluster.
- Server-side validation (if access): `kubectl apply --server-dry-run -f cluster/` — validates against cluster APIs.
- Apply a single file: `kubectl apply -f cluster/cluster-issuer.yaml` — creates/updates that resource.
- Inspect objects: `kubectl get crd,ns,issuer,certificate -A` — quick sanity check after changes.
- Optional lint: `yamllint cluster/` — run if you have yamllint installed.

## Coding Style & Naming Conventions
- YAML: 2-space indentation; no tabs. Keep keys stable and lowercase where possible.
- Filenames: kebab-case (e.g., `cluster-issuer.yaml`, `postgres-secret.yaml`).
- Structure: one file per kind; add a brief header comment with Kind/Name when helpful.
- Labels/annotations: prefer consistent ordering; include `app.kubernetes.io/*` labels when applicable.

## Testing Guidelines
- Pre-merge: run `kubectl apply --dry-run=client -f cluster/` and, if available, `--server-dry-run`.
- Post-apply verification: `kubectl get ... -n <ns>` and `kubectl describe <kind>/<name>` to confirm status and events.
- Keep manifests idempotent and environment-agnostic; document any required CRDs/namespaces in PRs.

## Commit & Pull Request Guidelines
- Commits: present-tense, imperative, scoped prefixes like `cluster:` or `docs:` (e.g., `cluster: add cert-manager cluster issuer`).
- PRs: include summary, rationale, affected paths, and validation steps (commands run, key `kubectl get/describe` output). Link issues.
- Avoid committing generated files; include only the manifests and supporting docs.

## Security & Configuration Tips
- Never commit secrets or `.env` files. Use Kubernetes `Secret`, SealedSecret, or an external secret manager.
- Ensure prerequisites (namespaces, CRDs like cert-manager) exist before applying dependent resources.
- Apply least-privilege RBAC; scope `ServiceAccount` and `Role` to the minimum needed.
