// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant STARTING_BALANCE = 10 ether;

    FundMe fundMe;
    address iz = makeAddr("iz");

    function setUp() external {
        // This is run before each test function

        DeployFundMe deployFundMe = new DeployFundMe();

        fundMe = deployFundMe.run();
        vm.deal(iz, STARTING_BALANCE);
    }

    modifier funded() {
        vm.prank(iz);
        fundMe.fund{value: (SEND_VALUE)}();
        assert(fundMe.getAddressToAmountFunded(iz) >= SEND_VALUE);
        _;
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWIthoutEnoughETH() public {
        vm.expectRevert(); // <- The next line after this one should revert! If not test fails.
        fundMe.fund(); // <- We send 0 value
    }

    function testFundUpdatesFundDataStructure() public {
        vm.prank(iz);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(iz);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        // Check that our sender iz is saved in the funders array at index 0
        vm.prank(iz);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, iz);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); // <- The next line after this one should revert! If not test fails.
        fundMe.withdraw(); // <- We are not the owner
    }

    function testWithdrawFromASingleFunder() public funded {
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 endingFundMeBalance = address(fundMe).balance;
        uint endingOwnerBalance = fundMe.getOwner().balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(endingOwnerBalance, startingOwnerBalance + startingFundMeBalance);
    }

    function testWithdrawFromMultipleFunders() public {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
        assert((numberOfFunders) * SEND_VALUE == fundMe.getOwner().balance - startingOwnerBalance);

    }
}

// Verbosity levels:
// - 2: Print logs for all tests
// - 3: Print execution traces for failing tests
// - 4: Print execution traces for all tests, and setup traces for failing tests

// - 5: Print execution and setup traces for all tests
