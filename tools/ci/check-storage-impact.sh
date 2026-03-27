#!/usr/bin/env bash
# check-storage-impact.sh
# Estimates storage size impact of contract changes.
# Run as part of CI before deploying contracts that add new fields.

set -euo pipefail

CONTRACTS_DIR="${1:-cadence/contracts}"
WARN_THRESHOLD_BYTES=5000   # Warn if a single resource exceeds this size

echo "=== Flow Storage Impact Check ==="
echo "Scanning: $CONTRACTS_DIR"
echo ""

total_new_fields=0
warnings=0

for f in $(find "$CONTRACTS_DIR" -name "*.cdc" 2>/dev/null); do
  # Count access(all) let/var fields (approximation of storage cost)
  field_count=$(grep -c "access(all) \(let\|var\)" "$f" 2>/dev/null || echo 0)
  resource_count=$(grep -c "access(all) resource " "$f" 2>/dev/null || echo 0)

  if [ "$resource_count" -gt 0 ]; then
    # Estimate: 200 bytes overhead + 80 bytes per field
    estimated_bytes=$(( 200 + field_count * 80 ))
    echo "$(basename $f): ~${estimated_bytes} bytes per resource (${field_count} fields)"
    if [ "$estimated_bytes" -gt "$WARN_THRESHOLD_BYTES" ]; then
      echo "  WARNING: Large resource — consider splitting fields or using off-chain metadata"
      warnings=$((warnings + 1))
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo "Warnings: $warnings"
echo ""
echo "Recommendations:"
echo "  - Keep NFT metadata <2KB per token for affordable minting"
echo "  - Use IPFS/Arweave for large metadata — store only the hash on-chain"
echo "  - Budget 0.001-0.01 FLOW per player for storage deposits"

if [ "$warnings" -gt 0 ]; then
  exit 1
fi
