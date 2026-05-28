# Remediation snippets

Render these as concrete manifests into `./k8s-hardening-out/<timestamp>/remediation/`. Substitute namespace/resource names from the finding. Always show the manifest to the user before applying.

---

## default-deny-netpol

Use when: namespace has no NetworkPolicy. **Warn:** this can break existing traffic — propose adding allow rules first, then default-deny.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <NAMESPACE>
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

---

## allow-dns-egress

Pair with default-deny so pods can resolve DNS.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: <NAMESPACE>
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
```

---

## restricted-pod-security

Enforce PSA `restricted` on a namespace.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <NAMESPACE>
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## hardened-securitycontext

Patch a Deployment to drop capabilities and run non-root.

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: <CONTAINER>
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

---

## disable-sa-automount

For default ServiceAccounts in non-system namespaces.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: <NAMESPACE>
automountServiceAccountToken: false
```

---

## remove-cluster-admin-binding

Replace a blanket `cluster-admin` binding with a narrowly scoped Role. Confirm with the user which verbs/resources the subject actually needs before applying.

```yaml
# Step 1: delete the over-broad binding
# kubectl delete clusterrolebinding <NAME>

# Step 2: create a scoped Role + RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <ROLE_NAME>
  namespace: <NAMESPACE>
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <BINDING_NAME>
  namespace: <NAMESPACE>
subjects:
  - kind: <SUBJECT_KIND>
    name: <SUBJECT_NAME>
    namespace: <SUBJECT_NAMESPACE>
roleRef:
  kind: Role
  name: <ROLE_NAME>
  apiGroup: rbac.authorization.k8s.io
```

---

## wildcard-rbac

Replace `verbs: ["*"]` or `resources: ["*"]` with the explicit list of verbs/resources the workload actually uses. Run `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>` after applying.

---

## resource-limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

---

## probes

```yaml
readinessProbe:
  httpGet: { path: /healthz, port: http }
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  httpGet: { path: /healthz, port: http }
  initialDelaySeconds: 15
  periodSeconds: 20
```

---

## etcd-encryption (managed-cluster note)

If the cluster is EKS/GKE/AKS, the user usually cannot edit the API server's `--encryption-provider-config`. Direct them to the provider's KMS envelope-encryption setting (EKS: KMS key in cluster config; GKE: Application-layer secrets encryption; AKS: KMS etcd encryption). Mark as "managed by provider" if unfixable.
