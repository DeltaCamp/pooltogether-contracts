/**
Copyright 2020 PoolTogether Inc.

This file is part of PoolTogether.

PoolTogether is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation under version 3 of the License.

PoolTogether is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PoolTogether.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.5.12;

import "./MCDAwarePool.sol";
import "./compound/IComptroller.sol";

contract AutonomousPool is MCDAwarePool {

  address internal constant COMP_RECIPIENT = 0x029Aa20Dcc15c022b1b61D420aaCf7f179A9C73f;

  uint256 public lastAwardTimestamp;
  uint256 public prizePeriodSeconds;
  IComptroller public comptroller;
  IERC20 public comp;

  event AwardedCOMP(
    address indexed recipient,
    uint256 amount
  );

  function initializeAutonomousPool(
    uint256 _lastAwardTimestamp,
    uint256 _prizePeriodSeconds,
    IERC20 _comp,
    IComptroller _comptroller
  ) external {
    require(address(comp) == address(0), "AutonomousPool/already-init");
    require(address(_comp) != address(0), "AutonomousPool/comp-not-defined");
    require(address(_comptroller) != address(0), "AutonomousPool/comptroller-not-defined");
    lastAwardTimestamp = _lastAwardTimestamp == 0 ? block.timestamp : _lastAwardTimestamp;
    prizePeriodSeconds = _prizePeriodSeconds;
    comptroller = _comptroller;
    comp = _comp;
    claimCOMP();
  }

  function isPrizePeriodEnded() public view returns (bool) {
    return (
      lastAwardTimestamp != 0 &&
      nextAwardAt() <= currentTime()
    );
  }

  function claimCOMP() public returns (uint256) {
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken;
    comptroller.claimComp(address(this), cTokens);
    uint256 amount = comp.balanceOf(address(this));
    comp.transfer(COMP_RECIPIENT, amount);
    return amount;
  }

  /**
   * @notice Locks the movement of tokens (essentially the committed deposits and winnings)
   * @dev The lock only lasts for a duration of blocks.  The lock cannot be relocked until the cooldown duration completes.
   */
  function lockTokens() public requireInitialized onlyPrizePeriodEnded {
    blocklock.lock(block.number);
  }

  /**
   * @notice Rewards the current committed draw using the passed secret, commits the current open draw, and opens the next draw using the passed secret hash.
   * Can only be called by an admin.
   * Fires the Rewarded event, the Committed event, and the Open event.
   */
  function reward() external requireInitialized onlyLocked nonReentrant {
    // if there is a committed draw, it can be awarded
    if (currentCommittedDrawId() > 0) {
      _reward();
    }
    if (currentOpenDrawId() != 0) {
      emitCommitted();
    }
    open();
    lastAwardTimestamp = currentTime();
  }

  /**
   * @notice Rewards the winner for the current committed Draw using the passed secret.
   * The gross winnings are calculated by subtracting the accounted balance from the current underlying cToken balance.
   * A winner is calculated using the revealed secret.
   * If there is a winner (i.e. any eligible users) then winner's balance is updated with their net winnings.
   * The draw beneficiary's balance is updated with the fee.
   * The accounted balance is updated to include the fee and, if there was a winner, the net winnings.
   * Fires the Rewarded event.
   */
  function _reward() internal {
    // require that there is a committed draw
    // require that the committed draw has not been rewarded
    uint256 drawId = currentCommittedDrawId();
    Draw storage draw = draws[drawId];
    bytes32 entropy = blockhash(block.number - 1);
    _reward(drawId, draw, entropy);
  }

  /**
   * @notice Opens a new Draw.
   */
  function open() internal {
    drawState.openNextDraw();
    draws[drawState.openDrawIndex] = Draw(
      nextFeeFraction,
      address(0),
      block.number,
      bytes32(0),
      bytes32(0),
      address(0),
      uint256(0),
      uint256(0)
    );
    emit Opened(
      drawState.openDrawIndex,
      address(0),
      bytes32(0),
      nextFeeFraction
    );
  }

  function nextAwardAt() public view returns (uint256) {
    return lastAwardTimestamp.add(prizePeriodSeconds);
  }

  function currentTime() internal view returns (uint256) {
    return block.timestamp;
  }

  modifier onlyPrizePeriodEnded() {
    require(isPrizePeriodEnded(), "AutonomousPool/prize-period-not-ended");
    _;
  }

  /**
   * @notice requires the caller to be an admin
   */
  modifier onlyAdmin() {
    revert("Pool/admin-disabled");
    _;
  }

  modifier requireInitialized() {
    require(address(comp) != address(0), "AutonomousPool/not-init");
    _;
  }
}
