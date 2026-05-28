# Shipping k8s-hardening as a project skill

If you'd rather bundle the skill with a specific repo (so anyone who clones it gets the skill automatically — no plugin install needed), drop the skill into the repo's `.claude/skills/` directory.

## Layout

```
your-repo/
├── .claude/
│   └── skills/
│       └── k8s-hardening/
│           ├── SKILL.md
│           ├── scripts/
│           │   ├── run-kube-bench.sh
│           │   ├── run-kubescape.sh
│           │   ├── run-trivy.sh
│           │   ├── rbac-sweep.sh
│           │   └── workload-sweep.sh
│           └── references/
│               ├── cis-checklist.md
│               ├── nsa-cisa-checklist.md
│               └── remediation-snippets.md
├── src/
└── ...
```

## One-shot copy

From the root of `your-repo`:

```bash
mkdir -p .claude/skills
cp -R /path/to/k8s-hardening-plugin/skills/k8s-hardening .claude/skills/k8s-hardening
chmod +x .claude/skills/k8s-hardening/scripts/*.sh
git add .claude/skills/k8s-hardening
git commit -m "Add k8s-hardening skill for cluster audit + remediation"
```

## When to pick this vs. the plugin

| Pick project skill if... | Pick plugin if... |
| --- | --- |
| The skill is closely tied to one repo / one cluster. | The skill should be available everywhere the user runs Claude Code. |
| You want zero install steps for collaborators. | You're publishing to a team or the public. |
| The skill embeds repo-specific knowledge (e.g. a custom values.yaml). | The skill is generic and reusable across projects. |

You can do both: ship the plugin for general use, and embed a thin project-skill that wraps it with repo-specific defaults.
