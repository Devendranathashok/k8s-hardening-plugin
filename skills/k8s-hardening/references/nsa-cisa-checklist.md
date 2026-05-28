# NSA/CISA Kubernetes Hardening Guide — quick triage map

The NSA/CISA guide organizes hardening into the categories below. Use this as a checklist when reviewing `kubescape scan framework nsa` output.

## 1. Pod security
- Run containers as non-root (`runAsNonRoot: true`).
- Use immutable container filesystems (`readOnlyRootFilesystem: true`).
- Scan images for vulnerabilities before deploy.
- Use only signed images from trusted registries.
- Drop ALL Linux capabilities; add back only what is needed.
- Disallow privileged containers and `hostPath` volumes.
- Apply seccomp `RuntimeDefault` and AppArmor/SELinux profiles.
- Enforce via Pod Security Admission (`restricted` where possible), OPA/Gatekeeper, or Kyverno.

## 2. Network separation and hardening
- Default-deny NetworkPolicies per namespace.
- Restrict control-plane and etcd ports to admin networks.
- Use a CNI that enforces NetworkPolicy.
- Encrypt traffic in transit; consider a service mesh with mTLS.
- Restrict egress to known destinations.

## 3. Authentication and authorization
- Disable anonymous authentication.
- Strong authentication (OIDC, x509 mTLS, cloud IAM) — no static tokens.
- RBAC: least privilege; no wildcard verbs/resources; no blanket `cluster-admin`.
- Disable `automountServiceAccountToken` where unused.
- Periodically audit RBAC bindings.

## 4. Audit logging and threat detection
- Enable API server audit logging at a useful metadata level.
- Forward logs to a SIEM; alert on suspicious verbs (`exec`, `attach`, `portforward`, secret reads).
- Deploy runtime detection (Falco, Tetragon).
- Monitor for privileged pod creation, hostPath mounts, and `kubectl exec`.

## 5. Upgrade and application security practices
- Apply security patches promptly; track CVEs in the cluster components and node OS.
- Periodically run vulnerability scans (`trivy k8s`).
- Rotate credentials and certificates (kubelet, etcd, service account signing keys).
- Remove unused components and idle resources.
- Test recovery: backups of etcd, disaster-recovery drills.

## Map to kubescape control IDs
`kubescape scan framework nsa --format json` emits findings with IDs like `C-0001` through `C-0099`. Common ones:
- `C-0001` Forbidden container registries
- `C-0009` Resource limits
- `C-0013` Non-root containers
- `C-0017` Immutable container filesystem
- `C-0034` Automatic mapping of service account
- `C-0035` Cluster-admin binding
- `C-0044` Container hostPort
- `C-0046` Insecure capabilities
- `C-0048` HostPath mount
- `C-0055` Linux hardening (seccomp/AppArmor/SELinux)
- `C-0057` Privileged container
- `C-0260` Missing NetworkPolicy
