URIP adalah platform DeFi yang memungkinkan tokenisasi aset tradisional dan pengelolaan reksadana melalui smart contract di jaringan Lisk.

## Features

### Dual Investment Tracks

1. **Direct Asset Investment**: Beli token individual (tAAPL, tTSLA, dll.)
2. **Mutual Fund Investment**: Beli URIP token untuk diversified portfolio

### Smart Contracts

- **AssetToken**: Token yang merepresentasikan individual assets
- **URIPToken**: Mutual fund token dengan dynamic NAV
- **PurchaseManager**: Handle pembelian kedua jenis investment

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (untuk npm scripts)

### Installation

```bash
# Clone repository
git clone <your-repo-url>
cd urip-smart-contracts

# Install dependencies
make install

# Or manually:
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
```

### Build

```bash
make build
# atau: forge build
```

### Test

```bash
make test
# atau: forge test -vvv

# Dengan gas report
make test-gas
```

### Deploy

#### Local Development

```bash
# Start local anvil node
anvil

# Deploy ke local (terminal baru)
make deploy-local
```

#### Lisk Sepolia Testnet

```bash
# Setup environment
cp .env.example .env
# Edit .env dengan private key dan RPC URL

# Deploy ke Lisk Sepolia
make deploy-lisk-sepolia PRIVATE_KEY=your_private_key
```

## Contract Architecture

### AssetToken.sol

- Represents individual assets (stocks, commodities)
- Oracle-based pricing mechanism
- 1:1 backing dengan real assets
- Role-based access control

### URIPToken.sol

- Mutual fund representation
- Dynamic NAV calculation
- Asset allocation tracking
- DAO governance integration

### PurchaseManager.sol

- Unified purchase interface
- Support multiple payment tokens
- Route ke direct atau mutual fund investment

## Testing

Contract dilengkapi dengan comprehensive test suite:

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testDirectAssetPurchase

# Run dengan verbose output
forge test -vvv

# Generate gas report
forge test --gas-report
```

## Usage Examples

### Direct Asset Purchase

```solidity
// Approve USDT
usdt.approve(address(purchaseManager), 300 * 1e6);

// Buy Apple tokens
purchaseManager.purchaseAssetToken(
    address(usdt),      // payment token
    address(appleToken), // asset token
    300 * 1e6           // amount
);
```

### Mutual Fund Purchase

```solidity
// Approve USDT
usdt.approve(address(purchaseManager), 1000 * 1e6);

// Buy URIP fund
purchaseManager.purchaseMutualFund(
    address(usdt),   // payment token
    1000 * 1e6       // amount
);
```

## Deployed Contracts (Lisk Sepolia)

_Update setelah deployment_

- MockUSDT: `0x...`
- Apple Token (tAAPL): `0x...`
- Tesla Token (tTSLA): `0x...`
- Google Token (tGOOGL): `0x...`
- Gold Token (tGOLD): `0x...`
- URIP Token: `0x...`
- Purchase Manager: `0x...`

## Security

- Multi-signature untuk critical operations
- Role-based access control
- Pausable contracts untuk emergency
- Reentrancy protection
- Comprehensive test coverage

## Contributing

1. Fork repository
2. Create feature branch
3. Write tests untuk new features
4. Ensure all tests pass
5. Submit pull request

## License

MIT License - see LICENSE file untuk details.
