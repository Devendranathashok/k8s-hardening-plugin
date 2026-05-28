#!/usr/bin/env bash
# Scan the live cluster for vulnerabilities, misconfigs, and exposed secrets.
# Output: $OUT_DIR/trivy-k8s.json
set -euo pipefail

OUT_DIR="${1:-./k8s-hardening-out}"
mkdir -p "$OUT_DIR"

if ! command -v trivy >/dev/null 2>&1; then
  echo "trivy not installed. Install: brew install trivy  (or https://aquasecurity.github.io/trivy/)" >&2
  exit 127
fi

trivy k8s cluster \
  --report all \
  --severity CRITICAL,HIGH,MEDIUM \
  --scanners vuln,misconfig,secret \
  --format json \
  --output "$OUT_DIR/trivy-k8s.json"
