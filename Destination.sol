// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    // Maps underlying token => wrapped token and vice versa
    mapping(address => address) public underlying_tokens;
    mapping(address => address) public wrapped_tokens;

    // List of all underlying tokens used
    address[] public tokens;

    event Creation(address indexed underlying_token, address indexed wrapped_token);
    event Wrap(address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount);
    event Unwrap(address indexed underlying_token, address indexed wrapped_token, address frm, address indexed to, uint256 amount);

    constructor(address admin) {
        require(admin != address(0), "Admin cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    /// @notice Create a new wrapped token for the given underlying token
    function createToken(
        address _underlying_token,
        string memory name,
        string memory symbol
    ) external onlyRole(CREATOR_ROLE) returns (address) {
        require(_underlying_token != address(0), "Invalid underlying token");
        require(underlying_tokens[_underlying_token] == address(0), "Token already exists");

        BridgeToken newToken = new BridgeToken(_underlying_token, name, symbol, address(this));
        address wrappedAddress = address(newToken);

        underlying_tokens[_underlying_token] = wrappedAddress;
        wrapped_tokens[wrappedAddress] = _underlying_token;
        tokens.push(_underlying_token);

        emit Creation(_underlying_token, wrappedAddress);
        return wrappedAddress;
    }

    /// @notice Mint wrapped tokens to a recipient
    function wrap(
        address _underlying_token,
        address _recipient,
        uint256 _amount
    ) external onlyRole(WARDEN_ROLE) {
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");

        address wrapped = underlying_tokens[_underlying_token];
        require(wrapped != address(0), "Underlying token not registered");

        BridgeToken(wrapped).mint(_recipient, _amount);

        emit Wrap(_underlying_token, wrapped, _recipient, _amount);
    }

    /// @notice Burn wrapped tokens and emit an unwrap event
    function unwrap(
        address _wrapped_token,
        address _recipient,
        uint256 _amount
    ) external {
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");

        address underlying = wrapped_tokens[_wrapped_token];
        require(underlying != address(0), "Wrapped token not registered");

        BridgeToken(_wrapped_token).burnFrom(msg.sender, _amount);

        emit Unwrap(underlying, _wrapped_token, msg.sender, _recipient, _amount);
    }

    /// @notice View function to get total supported tokens
    function getSupportedTokens() external view returns (address[] memory) {
        return tokens;
    }
}
