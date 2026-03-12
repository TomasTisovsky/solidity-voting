// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IZKVoteVerifier {
    function verifyVoteProof(
        bytes calldata proofData,
        bytes32 voterHash,
        uint256 eventId,
        uint256 mediaId,
        bool support
    ) external view returns (bool isValid, bool isLocalVoter);

    function verifyVCHashProof(
        bytes calldata proofData,
        bytes32 voterHash
    ) external view returns (bool isValid);
}