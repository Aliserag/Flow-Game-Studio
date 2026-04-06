# /flow-team

Orchestrate a full Flow blockchain feature from design to tested deployment.
This skill coordinates: cadence-specialist, flow-architect, qa-lead, and devops-engineer.

## Usage

```
/flow-team <feature-description>
```

## Workflow

### Stage 1: Architecture (flow-architect agent)
- Design contract interfaces, storage structure, capability graph
- Define entitlements required
- Produce ADR in `docs/architecture/flow/`

### Stage 2: Implementation (cadence-specialist agent)
- Write contracts following ADR
- Write transactions and scripts
- Must pass validate-cadence.sh hook

### Stage 3: Testing (qa-lead + cadence-specialist)
- Write tests for all public functions
- Run `flow test ./cadence/tests/...`
- All tests must pass before Stage 4

### Stage 4: CI Validation (devops-engineer)
- Confirm GitHub Actions pipeline passes
- Check contract size limits
- Confirm no Cadence 0.x patterns

### Stage 5: Deploy Handoff
- Generate testnet deploy command
- Flag any secrets that need GitHub Secrets configuration
- Provide post-deploy verification script checklist

## Example

```
/flow-team "Add crafting system: combine 3 GameItems to mint a rare GameNFT"
```

Output: Full ADR + contracts + transactions + tests + deploy instructions.
