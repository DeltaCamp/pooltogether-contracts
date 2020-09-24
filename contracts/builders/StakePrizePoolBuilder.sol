// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "../comptroller/ComptrollerInterface.sol";
import "./SingleRandomWinnerBuilder.sol";
import "../prize-pool/stake/StakePrizePoolProxyFactory.sol";

/* solium-disable security/no-block-members */
contract StakePrizePoolBuilder {
  using SafeMath for uint256;
  using SafeCast for uint256;

  struct StakePrizePoolConfig {
    IERC20 token;
    uint256 maxExitFeeMantissa;
    uint256 maxTimelockDuration;
  }

  event StakePrizePoolCreated (
    address indexed creator,
    address indexed prizePool,
    address indexed prizeStrategy
  );

  ComptrollerInterface public comptroller;
  StakePrizePoolProxyFactory public stakePrizePoolProxyFactory;
  SingleRandomWinnerBuilder public singleRandomWinnerBuilder;
  address public trustedForwarder;

  constructor (
    ComptrollerInterface _comptroller,
    address _trustedForwarder,
    StakePrizePoolProxyFactory _stakePrizePoolProxyFactory,
    SingleRandomWinnerBuilder _singleRandomWinnerBuilder
  ) public {
    require(address(_comptroller) != address(0), "CompoundPrizePoolBuilder/comptroller-not-zero");
    require(address(_singleRandomWinnerBuilder) != address(0), "CompoundPrizePoolBuilder/single-random-winner-builder-not-zero");
    require(address(_stakePrizePoolProxyFactory) != address(0), "StakePrizePoolBuilder/stake-prize-pool-proxy-factory-not-zero");
    comptroller = _comptroller;
    singleRandomWinnerBuilder = _singleRandomWinnerBuilder;
    trustedForwarder = _trustedForwarder;
    stakePrizePoolProxyFactory = _stakePrizePoolProxyFactory;
  }

  function createSingleRandomWinner(
    StakePrizePoolConfig calldata prizePoolConfig,
    SingleRandomWinnerBuilder.SingleRandomWinnerConfig calldata prizeStrategyConfig,
    uint8 decimals
  ) external returns (StakePrizePool) {
    StakePrizePool prizePool = _createStakePrizePool(
      prizePoolConfig,
      PrizePoolTokenListenerInterface(address(0x1)) // dummy strategy
    );

    prizePool.transferOwnership(address(singleRandomWinnerBuilder));

    SingleRandomWinner prizeStrategy = singleRandomWinnerBuilder.createSingleRandomWinner(
      prizePool,
      prizeStrategyConfig,
      decimals
    );

    prizePool.transferOwnership(msg.sender);
    prizeStrategy.transferOwnership(msg.sender);

    emit StakePrizePoolCreated(msg.sender, address(prizePool), address(prizeStrategy));

    return prizePool;
  }

  function _createStakePrizePool(
    StakePrizePoolConfig memory config,
    PrizePoolTokenListenerInterface prizeStrategy
  )
    internal
    returns (StakePrizePool)
  {
    StakePrizePool prizePool = stakePrizePoolProxyFactory.create();

    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      prizeStrategy,
      comptroller,
      tokens,
      config.maxExitFeeMantissa,
      config.maxTimelockDuration,
      config.token
    );

    return prizePool;
  }

  function createStakePrizePool(
    StakePrizePoolConfig calldata config,
    PrizePoolTokenListenerInterface prizeStrategy
  )
    external
    returns (StakePrizePool)
  {
    StakePrizePool prizePool = _createStakePrizePool(config, prizeStrategy);
    prizePool.transferOwnership(msg.sender);

    emit StakePrizePoolCreated(msg.sender, address(prizePool), address(prizeStrategy));

    return prizePool;
  }
}
