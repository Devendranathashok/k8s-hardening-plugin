#!/usr/bin/env bash
# Find risky workload configurations in the live cluster.
# Output: $OUT_DIR/workload-sweep.json
set -euo pipefail

OUT_DIR="${1:-./k8s-hardening-out}"
mkdir -p "$OUT_DIR"

PODS=$(kubectl get pods --all-namespaces -o json)

PRIVILEGED=$(echo "$PODS" | jq '[.items[] | select(.spec.containers[]?.securityContext.privileged == true) | {ns: .metadata.namespace, name: .metadata.name}]')

ROOT=$(echo "$PODS" | jq '[.items[] | select((.spec.securityContext.runAsNonRoot // false) != true and all(.spec.containers[]?; (.securityContext.runAsNonRoot // false) != true)) | {ns: .metadata.namespace, name: .metadata.name}]')

HOST_NS=$(echo "$PODS" | jq '[.items[] | select(.spec.hostNetwork == true or .spec.hostPID == true or .spec.hostIPC == true) | {ns: .metadata.namespace, name: .metadata.name, hostNetwork: .spec.hostNetwork, hostPID: .spec.hostPID, hostIPC: .spec.hostIPC}]')

NO_LIMITS=$(echo "$PODS" | jq '[.items[] | select(any(.spec.containers[]?; (.resources.limits // {}) == {})) | {ns: .metadata.namespace, name: .metadata.name}]')

NO_PROBES=$(echo "$PODS" | jq '[.items[] | select(any(.spec.containers[]?; .readinessProbe == null or .livenessProbe == null)) | {ns: .metadata.namespace, name: .metadata.name}]')

RO_FS=$(echo "$PODS" | jq '[.items[] | select(any(.spec.containers[]?; (.securityContext.readOnlyRootFilesystem // false) != true)) | {ns: .metadata.namespace, name: .metadata.name}]')

NS_NO_NETPOL=$(comm -23 \
  <(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort) \
  <(kubectl get netpol --all-namespaces -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u) \
  | jq -R . | jq -s .)

jq -n \
  --argjson privileged "$PRIVILEGED" \
  --argjson root "$ROOT" \
  --argjson host_ns "$HOST_NS" \
  --argjson no_limits "$NO_LIMITS" \
  --argjson no_probes "$NO_PROBES" \
  --argjson ro_fs "$RO_FS" \
  --argjson ns_no_netpol "$NS_NO_NETPOL" \
  '{privileged: $privileged, runs_as_root: $root, host_namespaces: $host_ns, missing_limits: $no_limits, missing_probes: $no_probes, writable_root_fs: $ro_fs, namespaces_without_networkpolicy: $ns_no_netpol}' \
  > "$OUT_DIR/workload-sweep.json"
