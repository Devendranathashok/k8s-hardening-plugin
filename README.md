# k8s-hardening — Claude Code plugin

Audit a **live** Kubernetes cluster against the CIS Kubernetes Benchmark and the NSA/CISA Kubernetes Hardening Guide, then generate and (with explicit per-change confirmation) apply remediation manifests.

The skill is high-blast-radius. It runs against the cluster pointed to by `kubectl config current-context` and can mutate RBAC, NetworkPolicies, Pod Security, and workload specs. Read [SKILL.md](skills/k8s-hardening/SKILL.md) for the full workflow and guardrails before installing.

## What's in the box

- **`skills/k8s-hardening/`** — the skill itself
  - `SKILL.md` — 5-phase workflow (preflight → audit → report → remediate → verify) with guardrails
  - `scripts/` — `kube-bench`, `kubescape`, `trivy`, RBAC sweep, workload sweep
  - `references/` — CIS + NSA/CISA triage maps, ready-to-render remediation YAML

## Install (as a plugin)

```bash
# Add this repo as a marketplace, then install the plugin
/plugin marketplace add https://github.com/Devendranathashok//k8s-hardening-plugin
/plugin install k8s-hardening
```

Updates flow through `/plugin marketplace update <name>`.

## Install (as a project skill)

If you'd rather ship the skill with a specific repo so every contributor gets it automatically, copy the skill folder into your repo:

```
your-repo/
  .claude/
    skills/
      k8s-hardening/    <- contents of skills/k8s-hardening/ from this plugin
        SKILL.md
        scripts/
        references/
```

Commit it. Anyone running Claude Code in the repo picks it up. See [examples/project-skill-layout.md](examples/project-skill-layout.md).

## Prerequisites

Install the audit tooling locally:

```bash
brew install kube-bench trivy jq
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
```

The skill will detect missing tools at preflight and refuse to silently skip them.

## Usage

In any Claude Code session, ask:

> "Run k8s-hardening on the current context"
> "Harden my cluster"
> "Audit my Kubernetes cluster for CIS and NSA findings"

Claude loads the skill via its description match. It will:

1. Show `kubectl config current-context` and ask you to confirm the target.
2. Run audits and write raw output + a normalized report to `./k8s-hardening-out/<timestamp>/`.
3. Propose remediations as YAML files in `./k8s-hardening-out/<timestamp>/remediation/`.
4. Apply only with explicit per-file confirmation. Never touches `kube-system` etc. without an explicit instruction.

## Safety notes

- **No silent mutations.** Every `kubectl apply` requires you to confirm.
- **Production contexts** require you to type the context name back.
- **Managed clusters** (EKS/GKE/AKS): control-plane CIS findings are flagged as "managed by provider" rather than auto-fixed.
- **Default-deny NetworkPolicies** can break traffic. The skill proposes a staged rollout (allow rules first, then default-deny) instead of dropping a deny on a busy namespace.

## License

MIT. See `LICENSE`.
