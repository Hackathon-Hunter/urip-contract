.PHONY: install build test deploy clean

install:
	@echo "Installing dependencies..."
	forge install OpenZeppelin/openzeppelin-contracts --no-commit
	forge install foundry-rs/forge-std --no-commit

build:
	@echo "Building contracts..."
	forge build

test:
	@echo "Running tests..."
	forge test -vvv

test-gas:
	@echo "Running tests with gas report..."
	forge test --gas-report

deploy-local:
	@echo "Deploying to local network..."
	forge script script/DeployURIP.s.sol:DeployURIP --rpc-url http://localhost:8545 --broadcast

deploy-lisk-sepolia:
	@echo "Deploying to Lisk Sepolia..."
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY not set"; exit 1; fi
	forge script script/DeployURIP.s.sol:DeployURIP --rpc-url https://rpc.sepolia-api.lisk.com --broadcast --verify --private-key $(PRIVATE_KEY)

clean:
	@echo "Cleaning build artifacts..."
	forge clean

setup:
	@echo "Setting up project..."
	make install
	make build
	@echo "Setup complete!"