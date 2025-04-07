// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Destination is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    mapping(address => address) public underlying_tokens;
    mapping(address => address) public wrapped_tokens;
    address[] public tokens;

    event Creation(address indexed underlying, address indexed wrapped);
    event Wrapped(address indexed sender, address indexed recipient, address indexed underlying, uint256 amount);
    event Unwrapped(address indexed sender, address indexed recipient, address indexed wrapped, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
    }

    function createToken(
        address _underlying_token,
        string memory name,
        string memory symbol
    ) public onlyRole(CREATOR_ROLE) returns (address) {
        require(_underlying_token != address(0), "Invalid underlying token");
        require(underlying_tokens[_underlying_token] == address(0), "Token already created");

        BridgeToken newToken = new BridgeToken(_underlying_token, name, symbol, address(this));
        address wrappedAddress = address(newToken);

        underlying_tokens[_underlying_token] = wrappedAddress;
        wrapped_tokens[wrappedAddress] = _underlying_token;
        tokens.push(_underlying_token);

        emit Creation(_underlying_token, wrappedAddress);
        return wrappedAddress;
    }

    function wrap(address _underlying, address _recipient, uint256 _amount) external {
        require(_underlying != address(0), "Invalid token");
        address wrapped = underlying_tokens[_underlying];
        require(wrapped != address(0), "Token not registered");
        require(_amount > 0, "Amount must be > 0");

        require(IERC20(_underlying).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        BridgeToken(wrapped).mint(_recipient, _amount);

        emit Wrapped(msg.sender, _recipient, _underlying, _amount);
    }

    function unwrap(address _wrapped, address _recipient, uint256 _amount) external {
        require(_wrapped != address(0), "Invalid token");
        address underlying = wrapped_tokens[_wrapped];
        require(underlying != address(0), "Token not registered");
        require(_amount > 0, "Amount must be > 0");

        BridgeToken(_wrapped).burnFrom(msg.sender, _amount);
        require(IERC20(underlying).transfer(_recipient, _amount), "Transfer failed");

        emit Unwrapped(msg.sender, _recipient, _wrapped, _amount);
    }

    function getWrappedToken(address _underlying) external view returns (address) {
        return underlying_tokens[_underlying];
    }

    function getUnderlyingToken(address _wrapped) external view returns (address) {
        return wrapped_tokens[_wrapped];
    }

    function getAllTokens() external view returns (address[] memory) {
        return tokens;
    }
}
