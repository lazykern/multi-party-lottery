// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract CommitReveal {
    struct Commit {
        bytes32 commit;
        uint64 block;
        bool revealed;
    }

    mapping(uint256 => Commit) internal commits;

    function commit(uint256 index, bytes32 dataHash) internal {
        commits[index].commit = dataHash;
        commits[index].block = uint64(block.number);
        commits[index].revealed = false;
        emit CommitHash(
            msg.sender,
            index,
            commits[index].commit,
            commits[index].block
        );
    }
    event CommitHash(
        address sender,
        uint256 index,
        bytes32 dataHash,
        uint64 block
    );

    function reveal(
        uint256 index,
        uint16 choice,
        string memory salt
    ) internal {
        //make sure it hasn't been revealed yet and set it to revealed
        require(
            commits[index].revealed == false,
            "CommitReveal::reveal: Already revealed"
        );
        commits[index].revealed = true;
        //require that they can produce the committed hash
        require(
            getSaltedHash(choice, salt) == commits[index].commit,
            "CommitReveal::reveal: Revealed hash does not match commit"
        );
        emit RevealChoice(msg.sender, choice, salt);
    }
    event RevealChoice(address sender, uint16 choice, string salt);

    function getSaltedHash(
        uint16 choice,
        string memory salt
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), choice, salt));
    }
}