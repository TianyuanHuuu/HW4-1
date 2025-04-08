// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../contracts/Destination.sol";
import "../contracts/BridgeToken.sol";

contract DestinationTest is Test {
    Destination public destination;
    address public admin;
    address public user;

    address public underlying;
    address public wrapped;

    function setUp() public {
        admin = address(this);
        user = address(0x1);
        destination = new Destination(admin);

        underlying = address(0x123);
        wrapped = destination.createToken(underlying, "WrappedToken", "WTKN");

        destination.grantRole(destination.WARDEN_ROLE(), admin);
    }

    function testCreation() public {
        address token = address(0x456);
        address wrapped2 = destination.createToken(token, "TestToken", "TT");
        assertEq(destination.underlying_tokens(token), wrapped2);
        assertEq(destination.wrapped_tokens(wrapped2), token);
    }

    function testApprovedWrap(address recipient, uint256 amount) public {
        // assume valid recipient and non-zero amount
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        destination.wrap(underlying, recipient, amount);

        uint256 balance = BridgeToken(wrapped).balanceOf(recipient);
        assertEq(balance, amount);
    }

    function testUnwrap(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);

        // Wrap first
        destination.wrap(underlying, user, amount);

        // Approve and unwrap
        vm.prank(user);
        BridgeToken(wrapped).approve(address(destination), amount);

        vm.prank(user);
        destination.unwrap(wrapped, to, amount);

        uint256 userBalance = BridgeToken(wrapped).balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testUnauthorizedCreation(address someone) public {
        vm.assume(someone != admin);
        vm.prank(someone);
        vm.expectRevert();
        destination.createToken(address(0x789), "Bad", "BAD");
    }

    function testUnregisteredApprovedWrap(address fakeUnderlying, address recipient, uint256 amount) public {
        vm.assume(fakeUnderlying != underlying);
        vm.assume(destination.underlying_tokens(fakeUnderlying) == address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        vm.expectRevert("Underlying token not registered");
        destination.wrap(fakeUnderlying, recipient, amount);
    }

    function testUnapprovedApprovedWrap(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        // Remove WARDEN_ROLE from admin
        destination.revokeRole(destination.WARDEN_ROLE(), admin);

        vm.expectRevert();
        destination.wrap(underlying, recipient, amount);
    }
}
