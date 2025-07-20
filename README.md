# Vesting Vault Smart Contract

A comprehensive time-locked token/equity vesting smart contract built on the Stacks blockchain using Clarity language.

## Overview

The Vesting Vault contract enables organizations to create time-locked vesting schedules for employees, advisors, or investors. It provides secure, automated token distribution over specified time periods with cliff protection and linear vesting mechanisms.

## Features

### 🔒 Time-Locked Vesting
- **Cliff Period**: Initial lockup period where no tokens can be claimed
- **Linear Vesting**: Gradual token release after cliff period
- **Block-Height Based**: Uses Stacks blockchain block heights for precise timing

### 👥 Multi-Beneficiary Support
- Create unlimited vesting schedules for different beneficiaries
- Each schedule is independent with custom parameters
- Individual tracking of claimed vs. available tokens

### 🛡️ Security & Access Control
- Owner-controlled authorization system
- Manager-based vesting schedule creation
- Emergency withdrawal capabilities
- Vesting schedule revocation

### 📊 Transparency
- Real-time vesting calculations
- Complete schedule visibility
- Claimable amount queries

## Contract Architecture

### Data Structures

**Vesting Schedule**
```clarity
{
  total-amount: uint,        ; Total tokens allocated
  claimed-amount: uint,      ; Tokens already claimed
  start-block: uint,         ; Vesting start block
  cliff-duration: uint,      ; Blocks until cliff ends
  vesting-duration: uint,    ; Total vesting period in blocks
  created-by: principal      ; Manager who created schedule
}
```

### Key Constants
- `CONTRACT-OWNER`: Immutable contract deployer address
- Error codes for comprehensive error handling
- Authorization and validation checks

## Functions

### Management Functions

#### `initialize-contract()`
- **Access**: Contract owner only
- **Purpose**: Set up initial contract state and owner as first manager
- **Returns**: `(ok true)` on success

#### `add-manager(manager: principal)`
- **Access**: Contract owner only
- **Purpose**: Authorize addresses to create vesting schedules
- **Parameters**: `manager` - Principal to authorize
- **Returns**: `(ok true)` on success

#### `remove-manager(manager: principal)`
- **Access**: Contract owner only
- **Purpose**: Revoke manager authorization
- **Parameters**: `manager` - Principal to deauthorize
- **Returns**: `(ok true)` on success

### Vesting Operations

#### `create-vesting-schedule(beneficiary, total-amount, cliff-duration, vesting-duration)`
- **Access**: Authorized managers only
- **Purpose**: Create new vesting schedule for beneficiary
- **Parameters**:
  - `beneficiary`: Principal receiving vested tokens
  - `total-amount`: Total tokens to vest (uint)
  - `cliff-duration`: Blocks until cliff ends (uint)
  - `vesting-duration`: Total vesting period in blocks (uint)
- **Returns**: `(ok true)` on success
- **Validation**: 
  - Amount > 0
  - Vesting duration > cliff duration
  - Beneficiary doesn't already have schedule

#### `claim-vested-tokens()`
- **Access**: Beneficiaries only
- **Purpose**: Claim available vested tokens
- **Returns**: `(ok claimable-amount)` with tokens claimed
- **Conditions**: Only claimable if tokens are vested and not yet claimed

#### `revoke-vesting(beneficiary: principal)`
- **Access**: Schedule creator or contract owner
- **Purpose**: Cancel vesting schedule and reclaim unvested tokens
- **Parameters**: `beneficiary` - Principal whose schedule to revoke
- **Returns**: `(ok remaining-amount)` with tokens returned

#### `emergency-withdraw(amount: uint)`
- **Access**: Contract owner only
- **Purpose**: Emergency token withdrawal
- **Parameters**: `amount` - Tokens to withdraw
- **Returns**: `(ok amount)` on success

### Query Functions

#### `get-vesting-schedule(beneficiary: principal)`
- **Returns**: Complete vesting schedule details or none
- **Purpose**: View beneficiary's vesting parameters

#### `get-vested-amount(beneficiary: principal)`
- **Returns**: Total tokens vested based on current block height
- **Purpose**: Calculate how many tokens have vested

#### `get-claimable-tokens(beneficiary: principal)`
- **Returns**: Tokens available for immediate claiming
- **Purpose**: Check claimable amount (vested - claimed)

#### `get-contract-balance()`
- **Returns**: Total tokens locked in contract
- **Purpose**: Monitor contract's token reserves

#### `is-manager(address: principal)`
- **Returns**: Boolean indicating manager status
- **Purpose**: Check if address can create vesting schedules

#### `get-contract-owner()`
- **Returns**: Contract owner principal
- **Purpose**: Identify contract owner

## Vesting Mathematics

### Linear Vesting Formula

The contract implements linear vesting after the cliff period:

```
If current_block < (start_block + cliff_duration):
    vested_amount = 0

Else if current_block >= (start_block + vesting_duration):
    vested_amount = total_amount

Else:
    elapsed_blocks = current_block - (start_block + cliff_duration)
    remaining_duration = vesting_duration - cliff_duration
    vested_amount = (total_amount × elapsed_blocks) ÷ remaining_duration
```

### Example Timeline

```
Block:     100    150    200    250    300    350    400
           |      |      |      |      |      |      |
           Start  Cliff  25%    50%    75%    100%   Complete
```

- **Start Block**: 100
- **Cliff Duration**: 50 blocks
- **Vesting Duration**: 200 blocks
- **Tokens Available**: 0% → 0% → 25% → 50% → 75% → 100%

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-UNAUTHORIZED | Caller lacks required permissions |
| u101 | ERR-INVALID-AMOUNT | Token amount must be > 0 |
| u102 | ERR-VESTING-NOT-FOUND | No vesting schedule exists |
| u103 | ERR-NOTHING-TO-CLAIM | No tokens available for claiming |
| u104 | ERR-INVALID-DURATION | Vesting duration must exceed cliff |
| u105 | ERR-ALREADY-EXISTS | Vesting schedule already exists |
| u106 | ERR-INSUFFICIENT-BALANCE | Contract lacks sufficient balance |

## Deployment Guide

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity CLI or Stacks development environment
- STX tokens for deployment

### Deployment Steps

1. **Deploy Contract**
   ```bash
   clarinet deploy --network testnet
   ```

2. **Initialize Contract**
   ```clarity
   (contract-call? .vesting-vault initialize-contract)
   ```

3. **Add Managers**
   ```clarity
   (contract-call? .vesting-vault add-manager 'SP1ABC...)
   ```

### Integration Example

```clarity
;; Create 4-year vesting with 1-year cliff
(contract-call? .vesting-vault create-vesting-schedule
  'SP1BENEFICIARY...
  u1000000  ;; 1M tokens
  u52560    ;; ~1 year cliff (assuming 10min blocks)
  u210240   ;; ~4 year total vesting
)

;; Beneficiary claims tokens
(contract-call? .vesting-vault claim-vested-tokens)
```

## Security Considerations

### Access Control
- Only authorized managers can create vesting schedules
- Beneficiaries can only claim their own tokens
- Owner maintains ultimate control with emergency functions

### Time Manipulation Resistance
- Uses blockchain block heights (immutable)
- No reliance on external time sources
- Predictable and verifiable timing

### Economic Security
- Prevents double-spending of vested tokens
- Accurate mathematical calculations
- Balance tracking prevents over-allocation

## Testing

### Unit Tests
- Vesting calculation accuracy
- Access control enforcement
- Error condition handling
- Edge case scenarios
