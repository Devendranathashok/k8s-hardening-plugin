#!/usr/bin/env bash
# Scan the live cluster against the NSA framework with kubescape.
# Output: $OUT_DIR/kubescape-nsa.json and kubescape-mitre.json
set -euo pipefail

OUT_DIR="${1:-./k8s-hardening-out}"
mkdir -p "$OUT_DIR"

if ! command -v kubescape >/dev/null 2>&1; then
  echo "kubescape not installed. Install: curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash" >&2
  exit 127
fi

kubescape scan framework nsa   --format json --output "$OUT_DIR/kubescape-nsa.json"   --verbose
kubescape scan framework mitre --format json --output "$OUT_DIR/kubescape-mitre.json" --verbose
