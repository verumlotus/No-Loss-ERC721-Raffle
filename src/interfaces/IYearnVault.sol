// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IYearnVault {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw() external returns (uint256);
}