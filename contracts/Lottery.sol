// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./Ownable.sol";

contract Lottery is Ownable, CommitReveal {
    uint16 constant MIN_CHOICE = 0;
    uint16 constant MAX_CHOICE = 999;
    uint256 constant COMMIT_FEE = 0.001 ether;

    enum Stage {
        IDLE,
        COMMITTING,
        REVEALING,
        JUDGING,
        JUDGEFAIL
    }
    Stage public currentStage;

    uint256 public maxParticipants; // N
    uint256 public commitingCloseTime; // start + T1
    uint256 public revealingCloseTime; // start + T1 + T2
    uint256 public judgingCloseTime; // start + T1 + T2 + T3

    uint256 public numParticipants;

    mapping(uint256 => Ticket) public tickets;

    struct Ticket {
        address committee;
        uint16 revealedChoice;
        bool isCommitted;
        bool isRevealed;
        bool isWithdrawn;
    }

    constructor(
        uint256 _maxParticipants, // N
        uint256 _commitStageDuration, // T1
        uint256 _revealStageDuration, //T2
        uint256 _judgeStageDuration // T3
    ) Ownable() CommitReveal() {
        // N
        maxParticipants = _maxParticipants;

        // start + T1
        commitingCloseTime = block.timestamp + _commitStageDuration;
        // start + T1 + T2
        revealingCloseTime = commitingCloseTime + _revealStageDuration;
        // start + T1 + T2 + T3
        judgingCloseTime = revealingCloseTime + _judgeStageDuration;
    }

    function getHashedLottery(uint16 _choice, string memory _salt)
        public
        view
        returns (bytes32)
    {
        require(_choice >= MIN_CHOICE && _choice <= MAX_CHOICE, "");
        
        return getSaltedHash(_choice, _salt);
    }


    function commitHashedLottery(bytes32 _hashedChoice)
        public
        payable
        returns (uint256)
    {
        require(block.timestamp < commitingCloseTime, "");

        require(numParticipants < maxParticipants, "");

        require(msg.value == COMMIT_FEE, "");

        if (currentStage == Stage.IDLE) {
            currentStage = Stage.COMMITTING;
        }

        uint256 ticketId = numParticipants;

        commit(ticketId, _hashedChoice);

        numParticipants++;

        tickets[ticketId] = Ticket({
            committee: msg.sender,
            revealedChoice: 1000,
            isRevealed: false,
            isWithdrawn: false
        });

        return ticketId;
    }

    function revealLottery(uint256 _ticketId, uint16 _choice, string memory _salt)
        public
    {
        require(
            block.timestamp >= commitingCloseTime &&
                block.timestamp < revealingCloseTime,
            ""
        );
        require(tickets[_ticketId].committee == msg.sender, "");

        reveal(_ticketId, _choice, _salt);

        tickets[_ticketId].revealedChoice = _choice;
        tickets[_ticketId].isRevealed = true;
    }
    
}
