function createToken(address _underlying_token, string memory name, string memory symbol) 
    public onlyRole(CREATOR_ROLE) returns (address) 
{
    require(_underlying_token != address(0), "Invalid underlying token");

    // Prevent duplicate creation
    require(wrapped_tokens[_underlying_token] == address(0), "Token already exists");

    // Deploy new wrapped token
    BridgeToken wrapped = new BridgeToken(name, symbol);
    address wrappedAddress = address(wrapped);

    // Map the tokens
    underlying_tokens[wrappedAddress] = _underlying_token;
    wrapped_tokens[_underlying_token] = wrappedAddress;
    tokens.push(_underlying_token);

    emit Creation(_underlying_token, wrappedAddress);
    return wrappedAddress;
}

function wrap(address _underlying_token, address _recipient, uint256 _amount) 
    public onlyRole(WARDEN_ROLE) 
{
    require(wrapped_tokens[_underlying_token] != address(0), "Token not registered");
    require(_recipient != address(0), "Invalid recipient");

    address wrapped = wrapped_tokens[_underlying_token];
    BridgeToken(wrapped).mint(_recipient, _amount);

    emit Wrap(_underlying_token, wrapped, _recipient, _amount);
}

function unwrap(address _wrapped_token, address _recipient, uint256 _amount) 
    public 
{
    require(underlying_tokens[_wrapped_token] != address(0), "Invalid wrapped token");
    require(_recipient != address(0), "Invalid recipient");

    BridgeToken wrapped = BridgeToken(_wrapped_token);
    require(wrapped.balanceOf(msg.sender) >= _amount, "Insufficient balance");

    wrapped.burnFrom(msg.sender, _amount);

    address underlying = underlying_tokens[_wrapped_token];
    emit Unwrap(underlying, _wrapped_token, msg.sender, _recipient, _amount);
}
