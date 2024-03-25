# Multi Party Lottery Smart Contract

A smart contract for a lottery system that allows multiple parties to participate in a lottery. The system is divided into multiple stages, each stage has a specific purpose and rules. The lottery is designed to be fair and transparent to all participants.

The contract is deployed on the Sepolia testnet at the address [0xe2dea45a974022223fbadb26423222b02cbf13f4](https://sepolia.etherscan.io/address/0xe2dea45a974022223fbadb26423222b02cbf13f4).

## Note

This project is a part of the Blockchain Engineering course at [Kasetsart University](https://www.ku.ac.th/).

## Mechanism

### Contract Stages

#### 1. Committing Stage

In this stage, participants have to hash their chosen lottery numbers via the `getHashedLottery` function and commit to the lottery by calling the `commitHashedLottery` function. The commit fee is 0.001 ether.

#### 2. Revealing Stage

In this stage, participants have to reveal their lottery numbers by calling the `revealLottery` function. The revealed lottery number must be between 0 and 999.

Those who do not reveal their lottery numbers within the revealing stage duration will not be eligible to win the lottery.

#### 3. Judging Stage

In this stage, the owner of the contract has to call the `judgeLottery` function to determine the winner of the lottery.

The winner is rewarded with 98% of the total lottery pool and the owner of the contract is rewarded with 2% of the total lottery pool and the contract is reset to the initial state.

In case of no valid participants, the owner is rewarded with the total lottery pool and the contract is reset to the initial state.

**If the owner does not call the `judgeLottery` function within the judging stage duration, the lottery can be refunded to all participants in stage 4.**

#### 4. Refunding Stage

In this stage, participants can refund their lottery fee if the lottery is not judged within the judging stage duration.

If all participants refund their lottery fee, the contract is reset to the initial state.

## Contract Details

### Phase Enum

```solidity
enum Phase {
    Commiting,
    Revealing,
    Judging,
    Refunding,
    Finished
}
```

The contract has a `Phase` enum to keep track of the current phase of the lottery.

### Lottery Ticket

```solidity
struct Ticket {
    address committee;
    uint16 revealedChoice;
    bool isRevealed;
    bool isRefundable;
}
```

The contract has a `Ticket` struct to store the details of a lottery ticket. Each ticket has the following fields:

1. `committee`: Address of the participant.
2. `revealedChoice`: The revealed lottery number.
3. `isRevealed`: Flag to indicate if the lottery number is revealed.
4. `isRefundable`: Flag to indicate if the ticket is refundable. (Used in the refunding stage)

### Contract Variables

```solidity
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
```

The contract has the following variables:

1. `currentPhase`: The current phase of the lottery.
2. `_hasBeenReset`: Flag to indicate if the contract has been reset.
3. `MIN_CHOICE`: Minimum lottery number allowed.
4. `MAX_CHOICE`: Maximum lottery number allowed.
5. `COMMIT_FEE`: The fee required to commit to the lottery.
6. `maxParticipants`: Maximum number of participants allowed in the lottery.
7. `T1`: Duration of the committing stage.
8. `T2`: Duration of the revealing stage.
9. `T3`: Duration of the judging stage.
10. `tStartTime`: Start time of the lottery.
11. `tCommittingCloseTime`: Closing time of the committing stage.
12. `tRevealingCloseTIme`: Closing time of the revealing stage.
13. `tjudgingCloseTime`: Closing time of the judging stage.
14. `numParticipants`: Number of participants in the lottery.
15. `tickets`: Mapping to store the lottery tickets.
16. `ticketIdOfAddress`: Mapping to store the ticket ID of an address.

### Constructor

```solidity
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
```

The contract constructor takes the following parameters:

1. `_maxParticipants`: Maximum number of participants allowed in the lottery.
2. `_commitStageDuration`: Duration of the committing stage.
3. `_revealStageDuration`: Duration of the revealing stage.
4. `_judgeStageDuration`: Duration of the judging stage.

### Committing Stage Functions

#### `commitHashedLottery`

```solidity
function commitHashedLottery(bytes32 _hashedChoice)
    public
    payable
    returns (uint256)
{
    if (
        currentPhase == Phase.Finished &&
        numParticipants == 0 &&
        block.timestamp >= tjudgingCloseTime
    ) {
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
```

The `commitHashedLottery` function allows participants to commit their lottery numbers. The function takes the following steps:

1. Checks if the current phase is `Finished` and there are no participants and the judging stage is closed, then it resets the contract and sets the current phase to `Commiting`.
2. Checks if the current time is within the committing stage duration.
3. Checks if the maximum number of participants has not been reached.
4. Checks if the commit fee is correct.
5. Generates a new ticket ID.
6. Commits the hashed lottery number.
7. Increments the number of participants.
8. Stores the ticket details in the contract.
9. Returns the ticket ID.

### Revealing Stage Functions

#### `revealLottery`

```solidity
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
```

The `revealLottery` function allows participants to reveal their lottery numbers. The function takes the following steps:

1. Checks if the current time is within the revealing stage duration.
2. Checks if the current phase is `Commiting`, then it sets the current phase to `Revealing`.
3. Checks if the lottery number is within the valid range.
4. Gets the ticket ID of the participant.
5. Checks if the participant is the owner of the ticket.
6. Checks if the ticket is not already revealed.
7. Reveals the lottery number.
8. Marks the ticket as revealed.

### Judging Stage Functions

#### `judgeLottery`

```solidity
function judgeLottery() public onlyOwner returns (uint16, address) {

    require(
        block.timestamp >= tRevealingCloseTIme &&
            block.timestamp < tjudgingCloseTime,
        "Judging phase is closed, please check current phase"
    );

    if (currentPhase == Phase.Revealing) {
        currentPhase = Phase.Judging;
    }

    require(
        currentPhase == Phase.Judging || currentPhase == Phase.Refunding,
        "You can't judge now, current phase is not Judging"
    );

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
```

The `judgeLottery` function allows the owner to judge the lottery and determine the winner. The function takes the following steps:

1. Checks if the current time is within the judging stage duration.
2. Checks if the current phase is `Revealing`, then it sets the current phase to `Judging`.
3. Checks if the current phase is `Judging` or `Refunding`.
4. Filters out the valid tickets.
5. If there are no valid tickets, rewards the owner and resets the contract. Otherwise, proceeds to the next step.
6. XORs the revealed lottery numbers to find the winning number.
7. Calculates the winner based on the winning number.
8. Rewards the winner and the owner.
9. Resets the contract.

**If the owner does not call the `judgeLottery` function within the judging stage duration, the lottery can be refunded to all participants in the refunding stage.**

### Refunding Stage Functions

#### `refundLottery`

```solidity
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
```

The `refundLottery` function allows participants to refund their lottery fee. The function takes the following steps:

1. Checks if the current time is within the refunding stage duration.
2. Checks if the current phase is `Judging` or `Refunding`.
3. Gets the ticket ID of the participant.
4. Checks if the participant is the owner of the ticket.
5. Checks if the ticket is refundable.
6. Transfers the commit fee back to the participant.
7. Marks the ticket as non-refundable.
8. Decrements the number of participants.
9. If all participants have refunded, resets the contract.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
