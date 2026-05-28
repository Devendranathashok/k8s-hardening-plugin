#!/usr/bin/env bash
# Enumerate dangerous RBAC: cluster-admin bindings, wildcard verbs/resources,
# and ServiceAccounts that auto-mount tokens.
# Output: $OUT_DIR/rbac-sweep.json
set -euo pipefail

OUT_DIR="${1:-./k8s-hardening-out}"
mkdir -p "$OUT_DIR"

CLUSTER_ADMIN_BINDINGS=$(kubectl get clusterrolebindings -o json \
  | jq '[.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}]')

WILDCARD_ROLES=$(kubectl get clusterroles,roles --all-namespaces -o json \
  | jq '[.items[] | select(.rules // [] | any(.verbs[]?=="*" or .resources[]?=="*")) | {kind: .kind, ns: .metadata.namespace, name: .metadata.name}]')

AUTOMOUNT_SAS=$(kubectl get sa --all-namespaces -o json \
  | jq '[.items[] | select((.automountServiceAccountToken // true) == true) | {ns: .metadata.namespace, name: .metadata.name}]')

jq -n \
  --argjson cluster_admin "$CLUSTER_ADMIN_BINDINGS" \
  --argjson wildcards "$WILDCARD_ROLES" \
  --argjson automount "$AUTOMOUNT_SAS" \
  '{cluster_admin_bindings: $cluster_admin, wildcard_roles: $wildcards, automount_sas: $automount}' \
  > "$OUT_DIR/rbac-sweep.json"
