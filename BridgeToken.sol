// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../contracts/Destination.sol";
import "../contracts/BridgeToken.sol";

contract DestinationTest is Test {
    Destination public destination;
    address public admin;
    address public user;
    address public underlyingToken;
    address public wrappedToken;

    function setUp() public {
        admin = address(this);
        user = address(0x1);

        // Deploy the Destination contract
        destination = new Destination(admin);

        // Use a mock address for the underlying token
        underlyingToken = address(0x123);

        // Create the wrapped token
        string memory name = "Wrapped Token";
        string memory symbol = "WTKN";
        wrappedToken = destination.createToken(underlyingToken, name, symbol);

        // Give the test contract WARDEN_ROLE for wrap calls
        destination.grantRole(destination.WARDEN_ROLE(), admin);
    }

    function testCreation() public {
        // Validate the wrapped token is correctly mapped
        assertEq(destination.underlying_tokens(underlyingToken), wrappedToken);
        assertEq(destination.wrapped_tokens(wrappedToken), underlyingToken);
    }

    function testApprovedWrap() public {
        uint256 amount = 1000;

        // Perform wrap
        destination.wrap(underlyingToken, user, amount);

        // Check user balance on wrapped token
        uint256 userBalance = BridgeToken(wrappedToken).balanceOf(user);
        assertEq(userBalance, amount);
    }

    function testUnwrap() public {
        uint256 amount = 500;

        // Mint tokens to user and approve unwrap
        destination.wrap(underlyingToken, user, amount);
        vm.prank(user);
        BridgeToken(wrappedToken).approve(address(destination), amount);

        // Simulate user calling unwrap
        vm.prank(user);
        destination.unwrap(wrappedToken, user, amount);

        // Check balance after unwrap
        uint256 balanceAfter = BridgeToken(wrappedToken).balanceOf(user);
        assertEq(balanceAfter, 0);
    }

    function testUnauthorizedCreation() public {
        // Another address without CREATOR_ROLE tries to create a token
        vm.prank(user);
        vm.expectRevert();
        destination.createToken(address(0x456), "Fake", "FAKE");
    }

    function testUnregisteredApprovedWrap() public {
        address unregistered = address(0x456);
        vm.expectRevert("Underlying token not registered");
        destination.wrap(unregistered, user, 100);
    }

    function testUnapprovedApprovedWrap() public {
        // Revoke WARDEN_ROLE from admin
        destination.revokeRole(destination.WARDEN_ROLE(), admin);

        vm.expectRevert();
        destination.wrap(underlyingToken, user, 100);
    }
}
