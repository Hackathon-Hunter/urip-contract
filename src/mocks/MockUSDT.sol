// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ============================================================================
// MOCK USDT DENGAN FAUCET (untuk testing)
// ============================================================================

contract MockUSDT is IERC20 {
    string public name = "Mock USDT";
    string public symbol = "USDT";
    uint8 public decimals = 6;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Faucet functionality
    mapping(address => uint256) public lastFaucetClaim;
    uint256 public faucetAmount = 1000 * 1e6; // 1000 USDT
    uint256 public faucetCooldown = 24 hours;

    // Only declare events that are NOT in IERC20
    event FaucetClaim(address indexed user, uint256 amount);

    constructor() {
        _totalSupply = 1000000 * 1e6; // 1M USDT
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");

        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    // Faucet function untuk testing
    function faucet() external {
        require(
            block.timestamp >= lastFaucetClaim[msg.sender] + faucetCooldown,
            "Faucet cooldown not met"
        );

        lastFaucetClaim[msg.sender] = block.timestamp;
        _balances[msg.sender] += faucetAmount;
        _totalSupply += faucetAmount;

        emit Transfer(address(0), msg.sender, faucetAmount);
        emit FaucetClaim(msg.sender, faucetAmount);
    }

    // Admin mint function
    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}