// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./Ownable.sol";

contract Lottery is Ownable, CommitReveal {
    enum Phase {
        Commiting,
        Revealing,
        Judging,
        Refunding,
        Finished
    }
    Phase internal currentPhase = Phase.Finished;

    bool private _hasBeenReset = true;

    uint16 constant MIN_CHOICE = 0;
    uint16 constant MAX_CHOICE = 999;
    uint256 constant COMMIT_FEE = 0.001 ether;

    uint256 public maxParticipants; // N

    uint256 public T1;
    uint256 public T2;
    uint256 public T3;

    uint256 public tStartTime = 0; // start
    uint256 public tCommittingCloseTime = 0; // start + T1
    uint256 public tRevealingCloseTIme = 0; // start + T1 + T2
    uint256 public tjudgingCloseTime = 0; // start + T1 + T2 + T3

    uint256 public numParticipants;

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256) public ticketIdOfAddress;

    struct Ticket {
        address committee;
        uint16 revealedChoice;
        bool isRevealed;
        bool isRefundable;
    }

    constructor(
        uint256 _maxParticipants, // N
        uint256 _commitStageDuration, // T1
        uint256 _revealStageDuration, //T2
        uint256 _judgeStageDuration // T3
    ) Ownable() CommitReveal() {
        // N
        maxParticipants = _maxParticipants;

        // T1, T2, T3
        T1 = _commitStageDuration;
        T2 = _revealStageDuration;
        T3 = _judgeStageDuration;
    }

    function getPhase()
        public
        view
        returns (
            Phase,
            string memory,
            uint256,
            uint256
        )
    {
        if (
            block.timestamp >= tStartTime && block.timestamp < tCommittingCloseTime
        ) {
            return (
                currentPhase,
                "Commiting",
                block.timestamp,
                tCommittingCloseTime
            );
        } else if (
            block.timestamp >= tCommittingCloseTime &&
            block.timestamp < tRevealingCloseTIme
        ) {
            return (
                currentPhase,
                "Revealing",
                block.timestamp,
                tRevealingCloseTIme
            );
        } else if (
            block.timestamp >= tRevealingCloseTIme &&
            block.timestamp < tjudgingCloseTime
        ) {
            return (currentPhase, "Judging", block.timestamp, tjudgingCloseTime);
        } else if (currentPhase == Phase.Refunding || !_hasBeenReset) {
            return (currentPhase, "Refunding", block.timestamp, 0);
        } else {
            return (currentPhase, "Finished", block.timestamp, 0);
        }
    }

    function getHashedLottery(uint16 _choice, string memory _salt)
        public
        view
        returns (bytes32)
    {
        require(
            _choice >= MIN_CHOICE && _choice <= MAX_CHOICE,
            "Invalid choice. Must be between 0 and 999"
        );

        return getSaltedHash(_choice, _salt);
    }

    function commitHashedLottery(bytes32 _hashedChoice)
        public
        payable
        returns (uint256)
    {


        if (currentPhase == Phase.Finished && numParticipants == 0 && block.timestamp >= tjudgingCloseTime) {
            _hasBeenReset = false;
            currentPhase = Phase.Commiting;

            tStartTime = block.timestamp;
            tCommittingCloseTime = tStartTime + T1;
            tRevealingCloseTIme = tCommittingCloseTime + T2;
            tjudgingCloseTime = tRevealingCloseTIme + T3;
        }

        require(
            block.timestamp >= tStartTime && block.timestamp < tCommittingCloseTime,
            "Not in commit phase, please check current phase"
        );

        require(
            numParticipants < maxParticipants,
            "Maximum number of participants reached"
        );

        require(msg.value == COMMIT_FEE, "Incorrect commit fee, should be 0.001 ether");

        uint256 ticketId = numParticipants;

        commit(ticketId, _hashedChoice);

        if (tickets[ticketId].committee == address(0)) {
            numParticipants++;
        }

        ticketIdOfAddress[msg.sender] = ticketId;

        tickets[ticketId] = Ticket({
            committee: msg.sender,
            revealedChoice: 1000,
            isRevealed: false,
            isRefundable: true
        });

        return ticketId;
    }

    function revealLottery(uint16 _choice, string memory _salt) public {
        require(
            block.timestamp >= tCommittingCloseTime &&
                block.timestamp < tRevealingCloseTIme,
            "Reveal phase is closed, please check current phase"
        );

        if (currentPhase == Phase.Commiting) {
            currentPhase = Phase.Revealing;
        }

        require(
            _choice >= MIN_CHOICE && _choice <= MAX_CHOICE,
            "Invalid choice. Must be between 0 and 999"
        );

        uint256 ticketId = ticketIdOfAddress[msg.sender];

        require(
            tickets[ticketId].committee == msg.sender,
            "You are not the owner of this ticket"
        );
        require(
            tickets[ticketId].isRevealed == false,
            "Ticket already revealed"
        );

        reveal(ticketId, _choice, _salt);

        tickets[ticketId].revealedChoice = _choice;

        tickets[ticketId].isRevealed = true;
    }

    function judgeLottery() public onlyOwner returns (uint16, address) {
        
        require(
            block.timestamp >= tRevealingCloseTIme &&
                block.timestamp < tjudgingCloseTime,
            "Judging phase is closed, please check current phase"
        );

        if (currentPhase == Phase.Revealing) {
            currentPhase = Phase.Judging;
        }

        Ticket[] memory validTickets = new Ticket[](numParticipants);
        uint256 validTicketCount = 0;
        for (uint256 i = 0; i < numParticipants; i++) {
            if (
                tickets[i].revealedChoice >= MIN_CHOICE &&
                tickets[i].revealedChoice <= MAX_CHOICE
            ) {
                validTickets[validTicketCount] = tickets[i];
                validTicketCount++;
            }
        }

        if (validTicketCount == 0) {
            _rewardOwnerAndReset();
            return (1000, address(0));
        }

        uint16 winningChoice = 0;
        for (uint16 i = 0; i < validTicketCount; i++) {
            winningChoice = winningChoice ^ validTickets[i].revealedChoice;
        }

        uint256 winnerIndex = uint256(
            keccak256(abi.encodePacked(winningChoice))
        ) % validTicketCount;

        address winner = validTickets[winnerIndex].committee;

        _rewardWinnerAndReset(winner);

        return (uint16(winningChoice), winner);
    }

    function refundLottery() public {
        require(block.timestamp >= tjudgingCloseTime, "Not in refund phase, please check current phase");

        require(
            currentPhase == Phase.Judging || currentPhase == Phase.Refunding,
            "You can't refund now, current phase is not Refunding"
        );

        uint256 ticketId = ticketIdOfAddress[msg.sender];

        require(
            tickets[ticketId].committee == msg.sender,
            "You are not the owner of this ticket"
        );
        require(tickets[ticketId].isRefundable, "Ticket is not refundable");

        payable(msg.sender).transfer(COMMIT_FEE);

        tickets[ticketId].isRefundable = false;
        numParticipants--;

        if (numParticipants == 0) {
            _reset();
        }
    }

    function _rewardOwnerAndReset() private {
        uint256 ownerReward = (COMMIT_FEE * numParticipants) / 100;

        payable(owner()).transfer(ownerReward);

        _reset();
    }

    function _rewardWinnerAndReset(address _winnerAddress) private {
        uint256 winnerReward = (COMMIT_FEE * numParticipants * 98) / 100;
        uint256 ownerReward = (COMMIT_FEE * numParticipants * 2) / 100;

        payable(_winnerAddress).transfer(winnerReward);
        payable(owner()).transfer(ownerReward);

        _reset();
    }

    function _reset() internal {
        _hasBeenReset = true;

        numParticipants = 0;
        currentPhase = Phase.Finished;

        tStartTime = 0;
        tCommittingCloseTime = 0;
        tRevealingCloseTIme = 0;
        tjudgingCloseTime = 0;

        for (uint256 i = 0; i < maxParticipants; i++) {
            tickets[i] = Ticket({
                committee: address(0),
                revealedChoice: 1000,
                isRevealed: false,
                isRefundable: false
            });
        }
    }
}
