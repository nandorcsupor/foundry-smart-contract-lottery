// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "forge-std/console.sol";

/**
 * @title Raffle
 * @author Raffle contract that allows users to enter a raffle and pick a winner
 * @notice This contract is for creating a sample raffle
 * @dev implements chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;

    // Duration of the lottery in seconds
    uint256 private immutable i_interval;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    //* Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
        // events
        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
    }

    // When is the winner supposed to be picked ?
    /**
        @dev This is the function that the Chainlink automation nodes call
        to see if its time to perfomn an upkeep
        The following should be true for this to return true:
        1. The time interval has passed between raffle runs
        2. The raffle is in the OPEN state
        3. The contract has ETH (aka players have entered)
        4. The subscription is funded with LINK
        * @return upkeepNeeded - true if the upkeep should be performed
     */
    function checkUpKeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = false;
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        // 0x0 = Blank bytes object
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id of the subscription ( I funded with link)
            REQUEST_CONFIRMATIONS, // number of block confirmations
            i_callBackGasLimit, // gas limit
            NUM_WORDS // number of random numbers
        );
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /* requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // Effects (our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit PickedWinner(winner);
        // Interactions
        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }
}
