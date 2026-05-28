#!/usr/bin/env bash
# Run CIS Kubernetes Benchmark via kube-bench against the current cluster.
# Output: $OUT_DIR/kube-bench.json
set -euo pipefail

OUT_DIR="${1:-./k8s-hardening-out}"
mkdir -p "$OUT_DIR"

if command -v kube-bench >/dev/null 2>&1; then
  kube-bench run --json > "$OUT_DIR/kube-bench.json"
  exit 0
fi

# Fall back to in-cluster Job using the official image.
JOB_NAME="kube-bench-$(date +%s)"
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: default
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      hostPID: true
      restartPolicy: Never
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:latest
          args: ["run", "--json"]
          volumeMounts:
            - { name: var-lib-etcd, mountPath: /var/lib/etcd, readOnly: true }
            - { name: var-lib-kubelet, mountPath: /var/lib/kubelet, readOnly: true }
            - { name: etc-kubernetes, mountPath: /etc/kubernetes, readOnly: true }
            - { name: usr-bin, mountPath: /usr/local/mount-from-host/bin, readOnly: true }
      volumes:
        - { name: var-lib-etcd,     hostPath: { path: /var/lib/etcd } }
        - { name: var-lib-kubelet,  hostPath: { path: /var/lib/kubelet } }
        - { name: etc-kubernetes,   hostPath: { path: /etc/kubernetes } }
        - { name: usr-bin,          hostPath: { path: /usr/bin } }
EOF

kubectl wait --for=condition=complete --timeout=300s "job/${JOB_NAME}" -n default
POD=$(kubectl get pods -n default -l "job-name=${JOB_NAME}" -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n default "$POD" > "$OUT_DIR/kube-bench.json"
kubectl delete job -n default "${JOB_NAME}" --wait=false
