// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./Ownable.sol";

contract Lottery is Ownable, CommitReveal {

    uint16 constant MIN_TICKET_NUMBER = 0;
    uint16 constant MAX_TICKET_NUMBER = 999;

    uint256 public maxParticipants; // N
    uint256 public commitingCloseTime; // start + T1
    uint256 public revealingCloseTime; // start + T1 + T2
    uint256 public judgingCloseTime; // start + T1 + T2 + T3

    uint256 private _numParticipants;


    struct Player {
        uint16 revealedChoice;
        bool isCommitted;
        bool isRevealed;
        bool isWithdrawn;
        address addr;
    }

    mapping(uint256 => Player) public players;

    constructor (
        uint256 _maxParticipants, // N
        uint256 _commitStageDuration, // T1
        uint256 _revealStageDuration, //T2
        uint256 _judgeStageDuration // T3
    ) {
        // N
        maxParticipants = _maxParticipants;

        // start + T1
        commitingCloseTime = block.timestamp + _commitStageDuration;
        // start + T1 + T2
        revealingCloseTime = commitingCloseTime + _revealStageDuration;
        // start + T1 + T2 + T3
        judgingCloseTime = revealingCloseTime + _judgeStageDuration;
    }

}