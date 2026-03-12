// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IZKVoteVerifier.sol";

contract MockZKVoteVerifier is IZKVoteVerifier {
    bool public voteValid = true;
    bool public vcHashValid = true;
    bool public local = true;

    function setVoteValid(bool value) external {
        voteValid = value;
    }

    function setVCHashValid(bool value) external {
        vcHashValid = value;
    }

    function setLocal(bool value) external {
        local = value;
    }

    function verifyVoteProof(
        bytes calldata,
        bytes32,
        uint256,
        uint256,
        bool
    ) external view returns (bool isValid, bool isLocalVoter) {
        return (voteValid, local);
    }

    function verifyVCHashProof(
        bytes calldata,
        bytes32
    ) external view returns (bool isValid) {
        return vcHashValid;
    }
}