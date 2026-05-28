---
name: k8s-hardening
description: Audit a live Kubernetes cluster against CIS Benchmark and NSA/CISA hardening guidance, then generate and (with explicit confirmation) apply remediation manifests. Use when the user asks to harden, audit, secure, or run a security scan on a Kubernetes cluster.
---

# Kubernetes Hardening (audit + remediate, live cluster)

This skill audits a **live** Kubernetes cluster and helps the user remediate findings. It is a high-blast-radius skill: scans read cluster state, and remediation can change RBAC, NetworkPolicies, Pod Security, and workload specs. **Never apply changes without explicit user confirmation per change-set.**

## Operating principles

1. **Confirm the target cluster before doing anything.** Print `kubectl config current-context` and the API server URL, and ask the user to confirm. Refuse to proceed against a context named like `prod`, `production`, `*-prod-*` unless the user re-confirms with the context name typed back.
2. **Audit first, remediate second.** Do not propose fixes until a scan has produced findings.
3. **Read-only by default.** All scanning uses read verbs (`get`, `list`). Never run `kubectl delete`, `kubectl apply`, `helm upgrade`, or `kubectl patch` without showing the user the diff and getting explicit approval.
4. **Generate manifests, don't mutate live objects directly.** Write remediation YAML into `./k8s-hardening-out/remediation/` so the user can review, commit, and apply via their normal GitOps flow. Offer `kubectl apply -f` only as a fallback.
5. **Group by severity and namespace.** A 200-finding wall of text is useless — cluster a report by severity, then namespace, then control ID.

## Workflow

### Phase 1 — Preflight

Run in parallel:
- `kubectl config current-context`
- `kubectl cluster-info`
- `kubectl version --short`
- `kubectl auth can-i --list` (to know what the current credentials can do)
- `kubectl get nodes -o wide`

Confirm with the user:
- The cluster context shown is the intended target.
- The user has authorization to scan and remediate this cluster.

If `kube-bench`, `kubescape`, or `trivy` are missing, tell the user the install command for their platform and stop until they install. Do not silently skip a tool.

### Phase 2 — Audit

Create an output directory: `./k8s-hardening-out/<timestamp>/`.

Run the audit tools and save raw output as JSON:

- `scripts/run-kube-bench.sh` — CIS Kubernetes Benchmark (control plane + nodes). Runs as a Job in the cluster.
- `scripts/run-kubescape.sh` — NSA/CISA + MITRE frameworks against live cluster.
- `scripts/run-trivy.sh` — `trivy k8s cluster` for vulnerabilities, misconfigs, and exposed secrets.
- Inline RBAC sweep: enumerate ClusterRoleBindings to `cluster-admin`, ServiceAccounts with token automount, and any Role/ClusterRole with `*` verbs or resources.
- Inline workload sweep: pods running as root, privileged pods, hostNetwork/hostPID/hostIPC, missing resource limits, missing readinessProbe/livenessProbe, missing securityContext.
- Inline network sweep: namespaces with no NetworkPolicy.

Each tool's findings get normalized into a single `findings.json` shaped like:

```json
{
  "id": "CIS-5.1.3",
  "source": "kube-bench",
  "severity": "high",
  "namespace": "default",
  "resource": "ClusterRoleBinding/dev-admin",
  "title": "Minimize wildcard use in Roles and ClusterRoles",
  "evidence": "...",
  "remediation_ref": "references/remediation-snippets.md#wildcard-rbac"
}
```

### Phase 3 — Report

Write `report.md` to the output dir with this structure:

```
# K8s Hardening Report — <context> — <timestamp>

## Summary
- Critical: N
- High: N
- Medium: N
- Low: N

## Critical findings
... (table: namespace, resource, control, evidence)

## High findings
...

## Recommended remediation order
1. ...
```

Print the summary to the user and link the file path.

### Phase 4 — Remediate

For each finding the user wants to fix:

1. Look up the matching snippet in `references/remediation-snippets.md`.
2. Render a concrete manifest into `./k8s-hardening-out/<timestamp>/remediation/<NN>-<short-name>.yaml`.
3. Show the user the manifest and (if it replaces an existing object) a diff against the live object: `kubectl get <kind> <name> -n <ns> -o yaml | diff - new.yaml`.
4. Only after explicit per-file confirmation, run `kubectl apply -f <file>`.
5. Re-run the relevant audit check to confirm the fix.

**Batching rules:**
- Group fixes that are obviously safe (adding default-deny NetworkPolicies in empty namespaces, adding `automountServiceAccountToken: false` to default SAs in non-system namespaces) and confirm as a batch.
- Never batch RBAC removals, PodSecurity standard changes, or anything touching `kube-system`. These are per-item confirmations.
- **Never touch `kube-system`, `kube-public`, or `kube-node-lease`** without an explicit user instruction naming the namespace.

### Phase 5 — Verify

After remediation, re-run the targeted scans for the controls you fixed and update `report.md` with a "Fixed in this session" section. Don't claim a fix worked unless the scan confirms it.

## Reference material

- [references/cis-checklist.md](references/cis-checklist.md) — CIS control IDs and one-line meanings, for triage.
- [references/nsa-cisa-checklist.md](references/nsa-cisa-checklist.md) — NSA/CISA Kubernetes Hardening Guide controls.
- [references/remediation-snippets.md](references/remediation-snippets.md) — Ready-to-render YAML for the most common findings.

## Guardrails (must follow)

- Do **not** disable admission controllers, audit logging, or TLS as a "fix" for noisy findings.
- Do **not** widen RBAC to silence a failing check.
- Do **not** delete resources to clear findings — propose a scoped fix instead.
- If a finding's remediation would cause downtime (e.g., adding default-deny NetworkPolicy to a namespace with existing traffic), warn the user and propose a staged rollout (label workloads, add allow rules, then default-deny).
- If the cluster is managed (EKS/GKE/AKS), some CIS control-plane checks are not user-fixable. Mark these as "managed by provider" in the report rather than proposing fixes.
