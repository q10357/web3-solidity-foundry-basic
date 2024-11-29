// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

// CodeConstants are defined in HelperConfig.s.sol
contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 raffleInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    /* Events - Had to Copy to "mock" an Emit  */
    event RaffleEntered(address indexed newPlayer);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    address public PLAYER = makeAddr("newPlayer");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        // Prepare test environment
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        // Deal some ETH to the newPlayer
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        /**
         * Our Raffle contract needs the specified parameters to be initiated
         * We can get these parameters from the HelperConfig contract
         */
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        raffleEntranceFee = config.entranceFee;
        raffleInterval = config.interval;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            //Mint some LINK tokens to the Raffle contract if local chain (for testing)
            link.mint(address(raffle), LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    modifier raffleEnteredAndTimePassed() {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}(); // balance and players are good
        vm.warp(block.timestamp + raffleInterval + 1); // interval is good (time passed)
        vm.roll(block.number + 1); // roll function to simulate a new block
        _;
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                            RAFFLE ENTRY TESTS
    //////////////////////////////////////////////////////////////*/
    /**
     * We need to send the correct amount of ETH to enter the raffle
     * If we don't send enough, the transaction will revert
     * NB: vm.prank() is a helper function that sends a transaction with a specified amount of ETH
     * it will only be applied to the next transaction (in this case, enterRaffle())
     */
    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_InsufficientETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersUponEntering() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: raffleEntranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert (NB: the expectEmit function will assert for us)
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /*
     * Test that the raffle reverts when attempting to enter while in CALCULATING state.
        state, wm.warp is able to change the block.timestamp (simulates time passing)
        It enables the performUpkeep() function to be called. PerormUpkeep() changes the state to CALCULATING
     **/
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEnteredAndTimePassed {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffleInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/
    /**
     * CheckUpkeep should return false if raffle has no balance
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + raffleInterval + 1); // interval is good
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert (balance is 0, and no players)
        assert(!upkeepNeeded);
    }

    /**
     * CheckUpkeep should return false if raffle is not open
     */
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleEnteredAndTimePassed {
        // Act
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // raffle is now in CALCULATING state
        // Assert
        assert(!upkeepNeeded);
    }

    /**
     * Checkupkeep returns false if defined interval has not passed
     * Not using wvm.warp to simulate time passing, the raffle contract should return false
     */
    function testCheckUpkeepReturnsFalseIfEnoughTimeNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}(); // balance and players are good
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    /**
     * CheckUpkeep should return true if:
     * - Raffle is open
     * - Enough time has passed
     * - Raffle has balance
     */
    function testCheckUpkeepReturnsTrueIfAllConditionsAreMet() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}(); // balance and players are good
        vm.warp(block.timestamp + raffleInterval + 1); // interval is good (time passed)
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    /**
     * You what what time it is!? It's time to test PerformUpkeep() !
     * Lets start by testing that it reverts if CheckUpkeep value is set to true
     */
    function testPerformupkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEnteredAndTimePassed {
        // Act / Assert
        // We dont need assert here, if it reverts, the test will fail
        raffle.performUpkeep("");
    }

    /**
     * Test that performUpkeep reverts if checkUpkeep is false
     */
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, numPlayers, rState));
        raffle.performUpkeep("");
    }

    /**
     * Test that performUpkeep updates raffle state to CALCULATING & emits requestID
     */
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestID() public raffleEnteredAndTimePassed {
        // Arrange in raffleEnteredAndTimePassed
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestID
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];
        // Assert
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(rState == Raffle.RaffleState.CALCULATING);
        assert(uint256(requestID) > 0);
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    /**
     * Test that fulfillRandomWords can only be called after performUpkeep
     * NB: when specify parameters in test, Foundry will generate a random value
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestID)
        public
        raffleEnteredAndTimePassed
    {
        // Arrange in raffleEnteredAndTimePassed
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(randomRequestID, address(raffle));
    }

    /**
     * Test that fulfillRandomWords picks a winner, resets the raffle state, and sends the balance to the winner
     * The final stage of our raffle! With all conditions met, the winner is picked
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed {
        // Arrange
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Pretend to be Chainlink VRF
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address winner = raffle.getRecentWinner();
        Raffle.RaffleState rState = raffle.getRaffleState();
        uint256 winnerBalance = winner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionalEntrants + 1);

        console2.log("Winner: ", winner);
        console2.log("expectedWinner: ", expectedWinner);
        assert(winner == expectedWinner);
        assert(rState == Raffle.RaffleState.OPEN); // RaffleState.OPEN
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimestamp);
    }
}
