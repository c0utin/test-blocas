// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract WrappedDAI is ERC20, ERC20Wrapper {
    using SafeERC20 for IERC20;

    constructor(IERC20 daiToken)
        ERC20("Wrapped DAI", "wDAI")
        ERC20Wrapper(daiToken)
    {}

    /// @notice Override decimals to resolve conflict between ERC20 and ERC20Wrapper
    function decimals() public view override(ERC20, ERC20Wrapper) returns (uint8) {
        return ERC20Wrapper.decimals();
    }

    /// @notice Wrap DAI into wDAI (1:1)
    function deposit(uint256 amount) external returns (uint256) {
        depositFor(msg.sender, amount);
        return amount;
    }

    /// @notice Unwrap wDAI into DAI (1:1)
    function withdraw(uint256 amount) external returns (uint256) {
        withdrawTo(msg.sender, amount);
        return amount;
    }
} 