#!/usr/bin/env bash
set -euo pipefail

FAILED=0

echo "=== Checking for Cadence 0.x patterns ==="

# Block on `pub ` (replaced by `access(all)` in Cadence 1.0)
if grep -rn '\bpub\b' cadence/contracts/ cadence/transactions/ cadence/scripts/ 2>/dev/null; then
  echo "FAIL: 'pub' keyword found — use 'access(all)' in Cadence 1.0"
  FAILED=1
fi

# Block on `priv ` (replaced by `access(self)`)
if grep -rn '\bpriv\b' cadence/contracts/ 2>/dev/null; then
  echo "FAIL: 'priv' keyword found — use 'access(self)' in Cadence 1.0"
  FAILED=1
fi

# Block on `AuthAccount` (replaced by `&Account` in Cadence 1.0)
if grep -rn 'AuthAccount' cadence/ 2>/dev/null; then
  echo "FAIL: 'AuthAccount' found — use '&Account' in Cadence 1.0"
  FAILED=1
fi

# Block on `self.account` in execute scope (not available in Cadence 1.0 transactions)
if grep -rn 'execute {' cadence/transactions/ 2>/dev/null | xargs grep -l 'self\.account' 2>/dev/null; then
  echo "FAIL: 'self.account' used in execute block — capture signer.address in prepare{} instead"
  FAILED=1
fi

if [ "$FAILED" -eq 1 ]; then
  echo "=== Cadence pattern check FAILED ==="
  exit 1
fi

echo "=== Cadence pattern check PASSED ==="
