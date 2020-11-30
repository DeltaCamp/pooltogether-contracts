// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "./MultipleWinners.sol";
import "../../external/openzeppelin/ProxyFactory.sol";

/// @title Creates a minimal proxy to the MultipleWinners prize strategy.  Very cheap to deploy.
contract MultipleWinnersProxyFactory is ProxyFactory {

  event MultipleWinnersCreated(address indexed winners);

  MultipleWinners public instance;

  constructor () public {
    instance = new MultipleWinners();
  }

  function create() external returns (MultipleWinners) {
    address result = MultipleWinners(deployMinimal(address(instance), ""));
    emit MultipleWinnersCreated(result);
    return MultipleWinners(result);
  }

}