# Random Number Generator Smart Contract

A secure and flexible pseudo-random number generator implemented in Clarity for the Stacks blockchain.

## Overview

This smart contract provides a robust solution for generating random numbers on the blockchain, which is inherently challenging due to the deterministic nature of blockchain technology. The implementation uses a two-step request-fulfill pattern to enhance security and combines multiple sources of entropy to improve randomness quality.

## Features

- **Two-step generation process**: Separates the request and fulfillment steps for enhanced security
- **Multiple entropy sources**: Combines various data points for better randomness
- **Configurable range**: Generate random numbers within any specified range
- **Optional user seeds**: Allow users to contribute to the randomness
- **Fee system**: Prevents spam and incentivizes contract maintenance
- **Administrative controls**: Fee adjustment and ownership transfer capabilities

## Security Considerations

The contract implements several security measures:

1. **Block confirmation requirement**: At least one block must be mined between request and fulfillment
2. **Seed validation**: User-provided seeds are capped to prevent manipulation
3. **Input validation**: All user inputs are validated before processing
4. **Entropy accumulation**: The contract maintains state across requests to improve randomness

## Technical Implementation

The random number generation uses a Linear Congruential Generator (LCG) algorithm with these parameters:
- Multiplier (a): 1664525
- Increment (c): 1013904223  
- Modulus (m): 4294967296 (2^32)

The entropy sources include:
- Current block height
- Previous block height difference
- Accumulated entropy from previous operations
- User-provided seeds
- Request IDs

## Usage

### Requesting a Random Number

```clarity
(contract-call? .random-number-generator request-random-number u1 u100 (some u42))
```

Parameters:
- `min` (uint): Lower bound of the random number range (inclusive)
- `max` (uint): Upper bound of the random number range (inclusive)
- `user-seed` (optional uint): Optional seed to contribute to randomness

Returns:
- `request-id` (uint): ID to use when fulfilling the request

### Fulfilling a Random Number Request

```clarity
(contract-call? .random-number-generator fulfill-random-number u1)
```

Parameters:
- `request-id` (uint): ID of the random number request to fulfill

Returns:
- `random-number` (uint): The generated random number within the requested range

### Getting Request Details

```clarity
(contract-call? .random-number-generator get-request u1)
```

Parameters:
- `request-id` (uint): ID of the request to query

Returns:
- Request details including requester, range, seed, and status

### Getting a Random Result

```clarity
(contract-call? .random-number-generator get-random-result u1)
```

Parameters:
- `request-id` (uint): ID of the request to get the result for

Returns:
- The generated random number if fulfilled, or `none` if not yet fulfilled

## Administrative Functions

### Setting the Fee

```clarity
(contract-call? .random-number-generator set-fee u2000)
```

Parameters:
- `new-fee` (uint): New fee amount in microSTX

### Transferring Ownership

```clarity
(contract-call? .random-number-generator transfer-ownership 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

Parameters:
- `new-owner` (principal): Principal address of the new contract owner

## Error Codes

- `ERR-UNAUTHORIZED (err u100)`: Caller doesn't have permission for the operation
- `ERR-INVALID-RANGE (err u101)`: Invalid min/max range specified
- `ERR-SEED-UNAVAILABLE (err u102)`: Not enough blocks have passed since request
- `ERR-INSUFFICIENT-FUNDS (err u103)`: Caller doesn't have enough STX to pay the fee
- `ERR-NO-SUCH-REQUEST (err u104)`: Request ID doesn't exist
- `ERR-INVALID-FEE (err u105)`: Attempted to set an invalid fee amount
- `ERR-INVALID-SEED (err u106)`: Invalid seed value provided

## Potential Use Cases

- Gaming applications (dice rolls, card shuffling)
- Lotteries and giveaways
- Random selection processes
- Fair distribution systems
- Randomized NFT attribute generation

## Limitations

While this contract provides a good solution for most use cases requiring randomness on the blockchain, it's important to note some limitations:

1. It's not cryptographically secure in the strictest sense
2. The randomness quality depends on block mining patterns
3. For very high-value applications, consider additional security measures