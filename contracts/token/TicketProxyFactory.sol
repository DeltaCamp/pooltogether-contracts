pragma solidity 0.6.4;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "./Ticket.sol";
import "../external/openzeppelin/ProxyFactory.sol";

/// @title Controlled ERC20 Token Factory
/// @notice Minimal proxy pattern for creating new Controlled ERC20 Tokens
contract TicketProxyFactory is Initializable, ProxyFactory {

  /// @notice Contract template for deploying proxied tokens
  Ticket public instance;

  /// @notice Initializes the Factory with an instance of the Controlled ERC20 Token
  function initialize () public initializer {
    instance = new Ticket();
  }

  /// @notice Creates a new Controlled ERC20 Token as a proxy of the template instance
  /// @return A reference to the new proxied Controlled ERC20 Token
  function create() external returns (Ticket) {
    return Ticket(deployMinimal(address(instance), ""));
  }
}
