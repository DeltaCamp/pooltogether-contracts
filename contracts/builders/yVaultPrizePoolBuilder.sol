// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "../comptroller/ComptrollerInterface.sol";
import "./SingleRandomWinnerBuilder.sol";
import "../prize-strategy/single-random-winner/SingleRandomWinnerProxyFactory.sol";
import "../prize-pool/yearn/yVaultPrizePoolProxyFactory.sol";
import "../token/ControlledTokenProxyFactory.sol";
import "../token/TicketProxyFactory.sol";
import "../external/yearn/yVaultInterface.sol";
import "../external/openzeppelin/OpenZeppelinProxyFactoryInterface.sol";

/* solium-disable security/no-block-members */
contract yVaultPrizePoolBuilder {
  using SafeMath for uint256;
  using SafeCast for uint256;

  struct yVaultPrizePoolConfig {
    yVaultInterface vault;
    uint256 reserveRateMantissa;
    uint256 maxExitFeeMantissa;
    uint256 maxTimelockDuration;
  }

  event yVaultPrizePoolCreated (
    address indexed creator,
    address indexed prizePool,
    address indexed prizeStrategy
  );

  ComptrollerInterface public comptroller;
  yVaultPrizePoolProxyFactory public vaultPrizePoolProxyFactory;
  SingleRandomWinnerBuilder public singleRandomWinnerBuilder;
  address public trustedForwarder;

  constructor (
    ComptrollerInterface _comptroller,
    address _trustedForwarder,
    yVaultPrizePoolProxyFactory _vaultPrizePoolProxyFactory,
    SingleRandomWinnerBuilder _singleRandomWinnerBuilder
  ) public {
    require(address(_comptroller) != address(0), "CompoundPrizePoolBuilder/comptroller-not-zero");
    require(address(_singleRandomWinnerBuilder) != address(0), "CompoundPrizePoolBuilder/single-random-winner-builder-not-zero");
    require(address(_vaultPrizePoolProxyFactory) != address(0), "yVaultPrizePoolBuilder/compound-prize-pool-builder-not-zero");
    comptroller = _comptroller;
    singleRandomWinnerBuilder = _singleRandomWinnerBuilder;
    trustedForwarder = _trustedForwarder;
    vaultPrizePoolProxyFactory = _vaultPrizePoolProxyFactory;
  }

  function createSingleRandomWinner(
    yVaultPrizePoolConfig calldata prizePoolConfig,
    SingleRandomWinnerBuilder.SingleRandomWinnerConfig calldata prizeStrategyConfig,
    uint8 decimals
  ) external returns (yVaultPrizePool) {
    yVaultPrizePool prizePool = _createyVaultPrizePool(
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

    emit yVaultPrizePoolCreated(msg.sender, address(prizePool), address(prizeStrategy));

    return prizePool;
  }

  function _createyVaultPrizePool(
    yVaultPrizePoolConfig memory config,
    PrizePoolTokenListenerInterface prizeStrategy
  )
    internal
    returns (yVaultPrizePool)
  {
    yVaultPrizePool prizePool = vaultPrizePoolProxyFactory.create();

    address[] memory tokens;

    prizePool.initialize(
      trustedForwarder,
      prizeStrategy,
      comptroller,
      tokens,
      config.maxExitFeeMantissa,
      config.maxTimelockDuration,
      config.vault,
      config.reserveRateMantissa
    );

    return prizePool;
  }

  function createyVaultPrizePool(
    yVaultPrizePoolConfig calldata config,
    PrizePoolTokenListenerInterface prizeStrategy
  )
    external
    returns (yVaultPrizePool)
  {
    yVaultPrizePool prizePool = _createyVaultPrizePool(config, prizeStrategy);
    prizePool.transferOwnership(msg.sender);

    emit yVaultPrizePoolCreated(msg.sender, address(prizePool), address(prizeStrategy));

    return prizePool;
  }
}
