# Security Audit Report — CoinFlip

**Date:** 2026-04-08
**Scope:** Full (contract + frontend)
**Contract:** `CoinFlip.cdc` deployed to Flow testnet at `0xeb24b78eb89a2076`
**Audited by:** security-engineer via `/security-audit`
**Files scanned:** `CoinFlip.cdc`, 6 transaction files, `CoinTossSection.tsx`, `PreviousWinners.tsx`, `flow.json`

---

## Executive Summary

| Severity | Count | Must Fix Before Mainnet |
|----------|-------|------------------------|
| CRITICAL | 3 | Yes — all |
| HIGH | 4 | Yes — all |
| MEDIUM | 6 | Recommended |
| LOW | 5 | Optional |

**Release recommendation: DO NOT SHIP TO MAINNET** — 3 CRITICAL and 4 HIGH findings open.

**Immediate action required:** SEC-001 (private key exposed in git). Rotate the testnet account key now.

---

## CRITICAL Findings

### SEC-001: Testnet Private Key Committed to Version Control
**Category:** Admin Key Security
**File:** `flow.json` — `accounts.testnet-account.key`
**Description:** The live testnet account private key for `0xeb24b78eb89a2076` is hardcoded in `flow.json` and committed to git. The account owner controls the Admin resource and all pool vaults.
**Attack scenario:** Anyone with repo read access can sign `commitToss`/`tossCoin` transactions as admin, time reveals to favourable block heights, or freeze pool resolution indefinitely trapping user funds.
**Remediation:** Rotate the key immediately via `flow keys generate`. Move the key to a gitignored file or CI env var (`$FLOW_TESTNET_KEY`). Add `flow.json` to `.gitignore` if it must reference keys.
**Effort:** Low — key rotation + CI secret setup.

---

### SEC-002: `commitToss` / `tossCoin` Are `access(all)` — No Entitlement Gate
**Category:** Access Control
**File:** `CoinFlip.cdc`, lines 342, 360
**Description:** Both Admin functions are `access(all)` with no entitlement requirement. Access is gated only by storage path isolation, not by compiler-enforced entitlements. Any future upgrade that accidentally publishes an Admin capability would expose full toss control publicly.
**Attack scenario:** A contract upgrade that adds any public Admin capability path immediately allows any account to control pool outcomes.
**Remediation:** Declare `entitlement AdminAction` and gate both functions with `access(AdminAction)`. Update the admin transaction borrows to request `auth(AdminAction)`.
**Effort:** Low.

---

### SEC-003: Reward Sum Rounding Can Exceed Vault Balance — Winner Claims Trapped
**Category:** Economic Security
**File:** `CoinFlip.cdc`, `headClaimReward` / `tailClaimReward`
**Description:** Winning shares are computed as `loserVaultBalance * share / 100.0` per winner. With many bettors, UFix64 rounding accumulation across individual share calculations can produce a total claim sum that slightly exceeds the actual vault balance. The final winner's `withdraw` panics, and since claim amounts are pre-set, all subsequent winners are permanently blocked from claiming.
**Attack scenario:** With ≥10 bettors on the losing side, rounding epsilons accumulate and the last winner's claim call panics. All prize funds are permanently stranded in `poolVault`.
**Remediation:** Track `totalPaid` and give the last claimant `vault.balance - totalPaid` rather than a formula-computed amount. Add a fuzz test verifying `sum(claimAmounts) ≤ available_vault_balance` for all pool configurations.
**Effort:** Medium.

---

## HIGH Findings

### SEC-004: `betOnHead` / `betOnTail` Accept Arbitrary `_addr` — Identity Spoofing
**Category:** Access Control
**File:** `CoinFlip.cdc` lines 250, 268; `betOnHead.cdc` line 19; `betOnTail.cdc` line 19
**Description:** Pool bet functions accept a caller-supplied `_addr: Address` with no check that `_addr` matches the transaction signer. An attacker can register bets under a victim's address while paying FLOW themselves.
**Attack scenario:** Attacker places a losing bet under victim's address. Victim can never bet for that pool (duplicate address) and cannot claim. Grief attack with no financial gain for attacker.
**Remediation:** Remove `_addr` parameter from pool bet functions. Derive address from the transaction's auth reference at the contract boundary. Never accept an address from an untrusted caller for ownership attribution.
**Effort:** Medium — requires contract upgrade + transaction update.

---

### SEC-005: No Guard Against Same Address Betting Both HEAD and TAIL
**Category:** Economic Security
**File:** `CoinFlip.cdc`, `betOnHead` / `betOnTail`
**Description:** An address can appear in both `headInfo` and `tailInfo` for the same pool, guaranteeing a win regardless of outcome and diluting the winning pool for honest players.
**Attack scenario:** User bets 1 FLOW HEAD and 1 FLOW TAIL. They always win. The `&&` check on `rewardClaimed` prevents double-withdrawal in one execution but the cross-side participation is not blocked.
**Remediation:** Add `pre { self.tailInfo[_addr] == nil }` to `betOnHead` and `pre { self.headInfo[_addr] == nil }` to `betOnTail`.
**Effort:** Low — one pre-condition per function.

---

### SEC-006: Admin Can Withhold `tossCoin` Indefinitely — Liveness Attack
**Category:** Randomness / VRF Integrity
**File:** `CoinFlip.cdc`, lines 342-355, 360-403
**Description:** After `commitToss`, there is no on-chain deadline requiring `tossCoin` to be called. The admin can delay resolution indefinitely, freezing all user funds.
**Attack scenario:** Admin observes the committed block height's beacon value, decides the outcome is unfavourable, and simply never calls `tossCoin`. All bets are locked until admin acts.
**Remediation:** Add a maximum-delay window (e.g., 100 blocks after `commitToss`). After that deadline, allow any user to call a permissionless `forceResolve(poolId)` that reads the committed beacon value and resolves the pool. Alternatively, allow users to reclaim bets after the deadline expires.
**Effort:** Medium.

---

### SEC-007: No Admin Sweep Path for Pool Vault Rounding Residuals
**Category:** Economic Security
**File:** `CoinFlip.cdc`, `claimReward`
**Description:** UFix64 rounding residuals accumulate permanently in closed pool vaults with no recovery path. There is no admin function to sweep residual balances from closed pools.
**Attack scenario:** On a busy contract, permanent FLOW accumulation in dead pool vaults grows over time. No exploit path, but unrecoverable funds.
**Remediation:** Add an admin-only `sweepPoolVault(poolId: UInt64)` gated behind the Admin resource that withdraws remaining balances from CLOSE-status pools to the platform fee account.
**Effort:** Low.

---

## MEDIUM Findings

### SEC-008: `PreviousWinners.tsx` Accesses `access(contract)` Fields Directly — Runtime Failure ✅ FIXED
**Category:** Access Control
**File:** `PreviousWinners.tsx`, lines 13, 21, 28 (original)
**Description:** Scripts accessed `pool.status.rawValue`, `pool.tossResult`, `pool.coinFlipped` directly. These are `access(contract)` in Cadence 1.0 — inaccessible from external scripts. Scripts silently fail, hiding all pool history and unclaimed rewards from users.
**Status:** Fixed — changed to `getStatus().rawValue`, `getTossResult()`, `isCoinFlipped()` getters.

---

### SEC-009: Deposit-Before-Record Pattern — Vault/Accounting Divergence Risk
**Category:** Economic Security
**File:** `CoinFlip.cdc`, lines 255-260
**Description:** The bet vault is deposited before `bet_amount` is recorded. A pre-condition weakening in a future upgrade could result in the vault holding more than `bet_amount` records show, creating untracked funds.
**Remediation:** Record `bet_amount` before depositing, or use post-deposit vault balance as the authoritative amount.
**Effort:** Low.

---

### SEC-010: `tossResult` Dual-Use as Commit Store Is Fragile
**Category:** Randomness / VRF Integrity
**File:** `CoinFlip.cdc`, lines 163-171, 350-354
**Description:** `tossResult` encodes committed block height as a decimal string during CALCULATING phase. An unexpected string value (from a future upgrade or maintenance error) would trap the pool in an unresolvable state with all bets permanently locked.
**Remediation:** Store committed block height in a separate `committedHeight: UInt64?` field when a contract upgrade permits it. Document the encoding in an ADR until then.
**Effort:** Low (documentation), Medium (contract upgrade when possible).

---

### SEC-011: No Minimum Bet Amount — Enables Micro-Bet Rounding Attacks
**Category:** Economic Security
**File:** `CoinFlip.cdc`, lines 251-254
**Description:** Bets of `1.0 FLOW` are accepted. At this scale, 1% fee arithmetic produces tiny fractional withdrawals that exacerbate the SEC-003 rounding issue.
**Remediation:** Enforce a minimum bet (e.g., `10.0 FLOW`) configurable via an admin parameter.
**Effort:** Low.

---

### SEC-012: No Client-Side Pool ID Validation Before `claimReward`
**Category:** Frontend Security
**File:** `CoinTossSection.tsx` lines 361-375; `PreviousWinners.tsx` lines 306-326
**Description:** No client-side check that pool ID is in range `[1, totalPools]` before submitting `claimReward`. User pays gas for a failed transaction if pool ID is invalid.
**Remediation:** Add `id >= 1 && id <= currentPoolId` guard before `fcl.mutate`.
**Effort:** Low.

---

### SEC-013: `getHeadBetUserInfo` / `getTailBetUserInfo` Force-Unwrap Optional — Fragile API
**Category:** Resource Safety
**File:** `CoinFlip.cdc`, lines 183-189
**Description:** Both getters use `!` on dictionary lookup. If called with an address not in the map, the transaction panics. All current call sites guard with existence checks, but the API itself is unsafe for future use.
**Remediation:** Return `&CoinFlip.HeadBet_User?` (optional reference) instead of force-unwrapping.
**Effort:** Low.

---

## LOW Findings

### SEC-014: `Math.random()` Coin Animation Misleads Users
**File:** `CoinTossSection.tsx`, lines 272-279
**Description:** Animation outcome is independent of blockchain result. Can show opposite result before blockchain response arrives.
**Remediation:** Tie animation outcome to `tossResult` value once resolved, or mark as purely decorative.

### SEC-015: Fee Applies to Bet Principal — May Not Match User Expectation
**File:** `CoinFlip.cdc`, lines 534-535
**Description:** 1% fee deducted from both principal and reward. Standard wagering expectation is fee on winnings only.
**Remediation:** Document fee structure clearly in contract doc comment and frontend UI.

### SEC-016: Raw FCL Error Messages Rendered to DOM
**File:** `CoinTossSection.tsx`, lines 337-338, 357-358, 373-374
**Description:** `e.message` from FCL errors rendered directly — leaks internal contract panic strings to users.
**Remediation:** Map known error strings to user-friendly messages; log raw errors to console only.

### SEC-017: `totalPools` Incremented Before Pool Resource Creation
**File:** `CoinFlip.cdc`, `Admin.createPool()` line 298
**Description:** Counter incremented before `create Pool()` — if pool creation panics, counter is corrupt.
**Remediation:** Increment after successful pool creation.

### SEC-018: `coinFlipped` Set After Claim-Amount Loop
**File:** `CoinFlip.cdc`, lines 459, 473
**Description:** Defensive ordering: `coinFlipped` should be set before transfers, not after.
**Remediation:** Set `coinFlipped = true` at start of `headClaimReward`/`tailClaimReward`.

---

## Fixes Applied in This Session

| ID | Status | Description |
|----|--------|-------------|
| SEC-008 | ✅ Fixed | `PreviousWinners.tsx` now uses `access(all)` getters |
| Polling bug | ✅ Fixed | `CoinTossSection.tsx` — stop-polling condition now checks `=== 'HEAD'/'TAIL'` not `!== ''` |
| Stale files | ✅ Removed | `commit_flip.cdc`, `reveal_flip.cdc`, `get_flip.cdc`, `get_all_flips.cdc` removed |

---

## Remediation Priority Order

**Immediate (before any further testnet use):**
1. SEC-001 — Rotate testnet key — Est. effort: Low
2. SEC-008 — ✅ Fixed

**Before mainnet deployment:**
3. SEC-003 — Reward sum rounding overflow — Medium
4. SEC-002 — Add AdminAction entitlement — Low
5. SEC-004 — Remove `_addr` parameter from bet functions — Medium
6. SEC-005 — Cross-side bet guard — Low
7. SEC-006 — Add `tossCoin` deadline / user escape hatch — Medium
8. SEC-007 — Admin sweep function for residuals — Low

**Before public launch:**
9. SEC-009, SEC-010, SEC-011, SEC-013, SEC-017, SEC-018

**Post-launch polish:**
10. SEC-012, SEC-014, SEC-015, SEC-016

---

## Re-Audit Trigger

Run `/security-audit quick` after remediating SEC-001 through SEC-007.
The Polish → Release gate requires this report with no open CRITICAL or HIGH items.

⛔ **CRITICAL security findings must be resolved before any mainnet deployment.**
