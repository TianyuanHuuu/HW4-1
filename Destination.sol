// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    // Maps source token -> wrapped token
    mapping(address => address) public wrapped_tokens;
    // Maps wrapped token -> source token
    mapping(address => address) public underlying_tokens;

    address[] public tokens;

    event Creation(address indexed underlying_token, address indexed wrapped_token);
    event Wrap(address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount);
    event Unwrap(address indexed underlying_token, address indexed wrapped_token, address from, address indexed to, uint256 amount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    /**
     * @notice Creates a wrapped token for the specified underlying token
     * @dev Only callable by accounts with CREATOR_ROLE
     */
    function createToken(address _underlying_token, string memory name, string memory symbol)
        public
        onlyRole(CREATOR_ROLE)
        returns (address)
    {
        require(_underlying_token != address(0), "Invalid token address");
        require(wrapped_tokens[_underlying_token] == address(0), "Token already wrapped");

        // Deploy wrapped token
        BridgeToken wrapped = new BridgeToken(name, symbol);
        address wrappedAddress = address(wrapped);

        // Set mappings
        wrapped_tokens[_underlying_token] = wrappedAddress;
        underlying_tokens[wrappedAddress] = _underlying_token;
        tokens.push(_underlying_token);

        emit Creation(_underlying_token, wrappedAddress);
        return wrappedAddress;
    }

    /**
     * @notice Mints wrapped tokens to the recipient
     * @dev Only callable by accounts with WARDEN_ROLE
     */
    function wrap(address _underlying_token, address _recipient, uint256 _amount)
        public
        onlyRole(WARDEN_ROLE)
    {
        address wrapped = wrapped_tokens[_underlying_token];
        require(wrapped != address(0), "Token not registered");
        require(_recipient != address(0), "Invalid recipient");

        BridgeToken(wrapped).mint(_recipient, _amount);

        emit Wrap(_underlying_token, wrapped, _recipient, _amount);
    }

    /**
     * @notice Burns wrapped tokens and emits unwrap event for off-chain processing
     */
    function unwrap(address _wrapped_token, address _recipient, uint256 _amount)
        public
    {
        address underlying = underlying_tokens[_wrapped_token];
        require(underlying != address(0), "Invalid wrapped token");
        require(_recipient != address(0), "Invalid recipient");

        BridgeToken token = BridgeToken(_wrapped_token);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        token.burnFrom(msg.sender, _amount);

        emit Unwrap(underlying, _wrapped_token, msg.sender, _recipient, _amount);
    }
}
