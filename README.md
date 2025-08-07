# BLOCAS DeFi Ecosystem

A comprehensive DeFi ecosystem built on Foundry featuring DAI wrapping, debenture shares with ownership tracking, and DAO governance.

## Overview

BLOCAS DeFi Ecosystem consists of four main smart contracts:

1. **WrappedDAI** - 1:1 DAI wrapper with deposit/withdraw functionality
2. **Debenture** - Percentage-based ownership tracking with sell blocking capabilities
3. **DAOGovernance** - Token-weighted voting system for decentralized decision making
4. **MockDAI** - Testing token for development and demonstrations

## Architecture

The system integrates multiple contracts to provide a complete decentralized finance solution:

- MockDAI provides stablecoin functionality for testing
- WrappedDAI offers 1:1 DAI wrapping capabilities
- Debenture tracks percentage ownership with share-based mechanics
- DAOGovernance enables token-weighted voting on proposals

## Features

### WrappedDAI
- 1:1 DAI wrapping and unwrapping
- OpenZeppelin ERC20Wrapper integration
- Decimal conflict resolution
- Simple deposit/withdraw interface

### Debenture
- Percentage ownership tracking
- Address-specific sell blocking
- Share-based ownership system
- Exchange rate monitoring
- Vault-like deposit/withdrawal mechanics

### DAO Governance
- Token-weighted voting power
- Proposal creation and execution
- Quorum requirements
- Multiple proposal states tracking
- 7-day voting periods

### MockDAI
- ERC20 testing token
- Unlimited minting capability
- 18 decimal precision

## Quick Start

### Prerequisites

- Nix with flakes enabled
- Git

### Installation

```bash
git clone <repository-url>
cd test-blocas
nix develop
```

### Build and Test

```bash
forge build
forge test
```

### Run Demo

```bash
forge script script/Demo.s.sol
```

## Testing

The project includes comprehensive test coverage with 44 passing tests:

- WrappedDAI Tests: 10 tests covering wrapping functionality
- Debenture Tests: 14 tests covering ownership and blocking features  
- DAO Tests: 20 tests covering governance mechanics

### Test Commands

```bash
# Run all tests
forge test

# Run specific test suite
forge test --match-contract WrappedDAITest
forge test --match-contract DebentureTest
forge test --match-contract DAOGovernanceTest

# Verbose output
forge test -vvv
```

## Automated Testing Script

For comprehensive testing with detailed reporting:

```bash
# Make executable (first time only)
chmod +x test.sh

# Run standard tests
./test.sh

# Run with options
./test.sh -v -g    # verbose + gas reporting
./test.sh -c       # coverage analysis
./test.sh --clean --demo  # clean build + demo
./test.sh --help   # show all options
```

### Script Features

- Dependency checking for Foundry tools and Nix environment
- Clean build artifact removal
- Smart contract compilation with error reporting
- Comprehensive test execution with detailed output
- Individual test suite isolation
- Test coverage report generation
- Gas usage analysis and reporting
- Demo script execution
- Project statistics and summary reporting

### Script Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Run tests with verbose output |
| `-c, --coverage` | Generate test coverage report |
| `-g, --gas` | Generate gas usage report |
| `--clean` | Clean build artifacts before testing |
| `--demo` | Run demo script after tests |
| `-h, --help` | Show help message |

## Deployment

### Local Deployment
```bash
forge script script/Deploy.s.sol
```

### Testnet Deployment
```bash
forge script script/Deploy.s.sol:DeployTestnet --rpc-url <testnet-rpc> --private-key <your-key>
```

### Mainnet Deployment
```bash
forge script script/Deploy.s.sol:DeployMainnet --rpc-url <mainnet-rpc> --private-key <your-key>
```

## Contract Specifications

### WrappedDAI
- Name: "Wrapped DAI"
- Symbol: "wDAI"
- Decimals: 18
- Ratio: 1:1 with underlying DAI

### Debenture
- Configurable name and symbol
- Decimals: 18
- Share calculation: `shares = (amount * totalSupply) / totalUnderlyingBacked`
- Owner-controlled sell blocking

### DAO Governance
- Voting period: 7 days
- Minimum proposal threshold: 1,000 tokens
- Quorum threshold: 10,000 tokens
- States: Active (0), Succeeded (1), Failed (2), Executed (3)

## Security Features

- ReentrancyGuard protection against reentrancy attacks
- Access control with owner-only functions
- SafeERC20 for secure token transfers
- Comprehensive input validation
- OpenZeppelin battle-tested contract libraries

### Governance Parameters

The DAO governance includes configurable parameters:

- Voting period: 7 days (604,800 seconds)
- Minimum proposal threshold: 1,000 tokens (prevents spam)
- Quorum threshold: 10,000 tokens (ensures participation)
- Execution window: Unlimited after voting ends

## Network Support

### Local Development
- Anvil local network
- Foundry testing environment

### Testnets
- Ethereum testnets (Goerli, Sepolia)
- Polygon testnets
- Any EVM-compatible testnet

### Mainnets
- Ethereum mainnet (with real DAI integration)
- Polygon mainnet
- Any EVM-compatible network

## Environment Configuration

Create a `.env` file for deployment:

```bash
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
ETHERSCAN_API_KEY=your_etherscan_key_here
```

## Project Structure

```
src/
├── WrappedDAI.sol      # DAI wrapper contract
├── Debenture.sol       # Ownership tracking with sell blocking
├── DAOGovernance.sol   # Governance and voting system
└── MockDAI.sol         # Testing token

test/
├── WrappedDAI.t.sol    # WrappedDAI comprehensive tests
├── Debenture.t.sol     # Debenture functionality tests
└── DAOGovernance.t.sol # DAO governance tests

script/
├── Deploy.s.sol        # Deployment scripts
└── Demo.s.sol          # Working demonstration script
```

## Development Guidelines

- Follow Solidity best practices
- Maintain high test coverage
- Use OpenZeppelin contracts where applicable
- Document all public functions with NatSpec
- Implement proper error handling and validation

## License

This project is licensed under the MIT License.

## Technical Assessment

For a detailed analysis of how this implementation exceeds technical test requirements, see [TECHNICAL_ASSESSMENT.md](./TECHNICAL_ASSESSMENT.md).

---

Built with Foundry, OpenZeppelin, and Nix