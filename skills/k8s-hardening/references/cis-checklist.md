# CIS Kubernetes Benchmark — quick triage map

One-liners for the control families most commonly flagged by `kube-bench`. Use this to triage; consult the full CIS Benchmark PDF for the authoritative text.

## 1. Control plane components
- **1.1.x** API server, controller-manager, scheduler, etcd file/dir permissions (640 or stricter, root-owned).
- **1.2.x** kube-apiserver flags: `--anonymous-auth=false`, `--authorization-mode=Node,RBAC`, `--audit-log-*` set, `--encryption-provider-config` set, `--tls-cipher-suites` restricted, no `AlwaysAdmit`, no `--insecure-port`.
- **1.3.x** kube-controller-manager: `--use-service-account-credentials=true`, `--profiling=false`, `--bind-address=127.0.0.1`.
- **1.4.x** kube-scheduler: `--profiling=false`, `--bind-address=127.0.0.1`.

## 2. etcd
- `--cert-file` / `--key-file` set, `--client-cert-auth=true`, `--auto-tls=false`, `--peer-*` mTLS, separate etcd CA.

## 3. Control plane configuration
- **3.1.x** Authentication: do not use token or basic auth files; integrate OIDC.
- **3.2.x** Logging: audit policy file set with minimum metadata level.

## 4. Worker nodes
- **4.1.x** kubelet service file + kubeconfig permissions 640 root-owned.
- **4.2.x** kubelet flags: `--anonymous-auth=false`, `--authorization-mode=Webhook`, `--read-only-port=0`, `--streaming-connection-idle-timeout` non-zero, `--make-iptables-util-chains=true`, `--event-qps=0`, `--tls-cert-file` + `--tls-private-key-file` set, `--rotate-certificates=true`, `RotateKubeletServerCertificate=true`.

## 5. Policies (workload + cluster posture)
- **5.1.x** RBAC: minimize `cluster-admin`, wildcards, and use of `default` SA. Disable `automountServiceAccountToken` where not needed.
- **5.2.x** Pod Security Standards: enforce `baseline` minimum, prefer `restricted`. No privileged, hostNetwork/PID/IPC, hostPath, NET_RAW, sharing host namespaces.
- **5.3.x** Network: every namespace has a NetworkPolicy; CNI supports them.
- **5.4.x** Secrets: prefer external secret managers; do not pass secrets via env vars where files work.
- **5.7.x** General: Seccomp `RuntimeDefault`, AppArmor profiles set, no default namespace usage.

## Managed-cluster carve-outs
On EKS/GKE/AKS the **1.x** control-plane controls are not user-fixable — mark as "managed by provider" in the report. Focus user-actionable work on **4.x** (node) and **5.x** (workload/RBAC/network) sections.
