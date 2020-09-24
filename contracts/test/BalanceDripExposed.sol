pragma solidity >=0.6.0 <0.7.0;

import "../drip/BalanceDrip.sol";

contract BalanceDripExposed {
  using BalanceDrip for BalanceDrip.State;

  event Dripped(
    address indexed user,
    uint256 newTokens
  );

  BalanceDrip.State internal dripState;

  function setDripRate(
    uint256 measureTotalSupply,
    uint256 dripRatePerSecond,
    uint32 currentTime
  ) external {
    dripState.setDripRate(measureTotalSupply, dripRatePerSecond, currentTime);
  }

  function poke(
    address user,
    uint256 userMeasureBalance
  ) external returns (uint256) {
    uint256 newTokens = dripState.poke(
      user,
      userMeasureBalance
    );

    emit Dripped(user, newTokens);

    return newTokens;
  }

  function drip(
    address user,
    uint256 userMeasureBalance,
    uint256 measureTotalSupply,
    uint256 currentTime
  ) external returns (uint256) {
    uint256 newTokens = dripState.drip(
      user,
      userMeasureBalance,
      measureTotalSupply,
      currentTime
    );

    emit Dripped(user, newTokens);

    return newTokens;
  }

  function dripTwice(
    address user,
    uint256 userMeasureBalance,
    uint256 measureTotalSupply,
    uint256 currentTime
  ) external returns (uint256) {
    uint256 newTokens = dripState.drip(
      user,
      userMeasureBalance,
      measureTotalSupply,
      currentTime
    );

    newTokens = newTokens + dripState.drip(
      user,
      userMeasureBalance,
      measureTotalSupply,
      currentTime
    );

    emit Dripped(user, newTokens);

    return newTokens;
  }

  function exchangeRateMantissa() external view returns (uint256) {
    return dripState.exchangeRateMantissa;
  }

  function totalDripped() external view returns (uint256) {
    return dripState.totalDripped;
  }

  function resetTotalDripped() external {
    dripState.resetTotalDripped();
  }
}
