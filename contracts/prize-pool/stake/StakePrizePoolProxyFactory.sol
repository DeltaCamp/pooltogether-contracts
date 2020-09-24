// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0 <0.7.0;

import "./StakePrizePool.sol";
import "../../external/openzeppelin/ProxyFactory.sol";

/// @title yVault Prize Pool Proxy Factory
/// @notice Minimal proxy pattern for creating new yVault Prize Pools
contract StakePrizePoolProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied Prize Pools
  StakePrizePool public instance;

  /// @notice Initializes the Factory with an instance of the yVault Prize Pool
  constructor () public {
    instance = new StakePrizePool();
  }

  /// @notice Creates a new yVault Prize Pool as a proxy of the template instance
  /// @return A reference to the new proxied yVault Prize Pool
  function create() external returns (StakePrizePool) {
    return StakePrizePool(deployMinimal(address(instance), ""));
  }
}
