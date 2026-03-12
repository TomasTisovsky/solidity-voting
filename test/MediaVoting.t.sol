// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MediaVoting.sol";
import "../src/MockZKVoteVerifier.sol";

contract MediaVotingTest is Test {
    MediaVoting voting;
    MockZKVoteVerifier mockVerifier;

    address constant NON_OWNER = address(0xBEEF);

    // Test constants
    string constant EVENT_NAME = "Protest in Bratislava";
    string constant EVENT_LOCATION = "Bratislava";
    uint64 constant EVENT_TIMESTAMP = 1_700_000_000;
    string constant REPORTER_NAME = "John Reporter";
    string constant REPORTER_ORG = "Daily News";

    string constant MEDIA_URI_1 = "ipfs://media1";
    string constant MEDIA_DESC_1 = "Police at the main square";
    string constant MEDIA_TYPE_1 = "image";

    string constant MEDIA_URI_2 = "ipfs://media2";
    string constant MEDIA_DESC_2 = "Crowd marching through the city";
    string constant MEDIA_TYPE_2 = "video";

    bytes constant DUMMY_VOTE_PROOF = hex"1234";
    bytes constant DUMMY_VC_HASH_PROOF = hex"5678";

    function setUp() public {
        voting = new MediaVoting();
        mockVerifier = new MockZKVoteVerifier();
    }

    function _emptyMediaInputs() internal pure returns (MediaVoting.MediaInput[] memory inputs) {
        inputs = new MediaVoting.MediaInput[](0);
    }

    function _oneMediaInput() internal pure returns (MediaVoting.MediaInput[] memory inputs) {
        inputs = new MediaVoting.MediaInput[](1);
        inputs[0] = MediaVoting.MediaInput({
            uri: MEDIA_URI_1,
            description: MEDIA_DESC_1,
            mediaType: MEDIA_TYPE_1
        });
    }

    function _twoMediaInputs() internal pure returns (MediaVoting.MediaInput[] memory inputs) {
        inputs = new MediaVoting.MediaInput[](2);
        inputs[0] = MediaVoting.MediaInput({
            uri: MEDIA_URI_1,
            description: MEDIA_DESC_1,
            mediaType: MEDIA_TYPE_1
        });
        inputs[1] = MediaVoting.MediaInput({
            uri: MEDIA_URI_2,
            description: MEDIA_DESC_2,
            mediaType: MEDIA_TYPE_2
        });
    }

    function _createDefaultEventWithNoMedia() internal returns (uint256 eventId) {
        MediaVoting.MediaInput[] memory inputs = _emptyMediaInputs();

        eventId = voting.createEvent(
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG,
            inputs
        );
    }

    function _createDefaultEventWithOneMedia() internal returns (uint256 eventId) {
        MediaVoting.MediaInput[] memory inputs = _oneMediaInput();

        eventId = voting.createEvent(
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG,
            inputs
        );
    }

    function _createDefaultEventWithTwoMedia() internal returns (uint256 eventId) {
        MediaVoting.MediaInput[] memory inputs = _twoMediaInputs();

        eventId = voting.createEvent(
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG,
            inputs
        );
    }

    function _setupZKVerifierAndEnable(bool enableVoting, bool enableVCHash) internal {
        voting.setZKVerifier(address(mockVerifier));
        voting.setZKMode(enableVoting, enableVCHash);
    }

    function testOwnerIsDeployer() public {
        assertEq(voting.owner(), address(this));
    }

    function testCreateEventStoresDataCorrectly() public {
        uint256 eventId = _createDefaultEventWithNoMedia();

        assertEq(eventId, 0, "First eventId should be 0");

        (
            uint256 storedId,
            string memory storedName,
            string memory storedLocation,
            uint64 storedTimestamp,
            address storedReporter,
            string memory storedReporterName,
            string memory storedReporterOrg,
            uint256 mediaCount
        ) = voting.getEvent(eventId);

        assertEq(storedId, eventId);
        assertEq(storedName, EVENT_NAME);
        assertEq(storedLocation, EVENT_LOCATION);
        assertEq(storedTimestamp, EVENT_TIMESTAMP);
        assertEq(storedReporter, address(this));
        assertEq(storedReporterName, REPORTER_NAME);
        assertEq(storedReporterOrg, REPORTER_ORG);
        assertEq(mediaCount, 0);
    }

    function testCreateEventEmitsEventCreated() public {
        MediaVoting.MediaInput[] memory inputs = _emptyMediaInputs();

        vm.expectEmit(true, true, false, true);
        emit MediaVoting.EventCreated(
            0,
            address(this),
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG
        );

        voting.createEvent(
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG,
            inputs
        );
    }

    function testCreateEventWithInitialMediaStoresEverythingCorrectly() public {
        uint256 eventId = _createDefaultEventWithTwoMedia();

        assertEq(eventId, 0);
        assertEq(voting.getEventCount(), 1);
        assertEq(voting.getMediaCountForEvent(eventId), 2);

        (
            uint256 mediaId0,
            string memory uri0,
            string memory desc0,
            string memory type0,
            uint256 yes0,
            uint256 no0,
            uint256 localYes0,
            uint256 localNo0
        ) = voting.getMediaItem(eventId, 0);

        assertEq(mediaId0, 0);
        assertEq(uri0, MEDIA_URI_1);
        assertEq(desc0, MEDIA_DESC_1);
        assertEq(type0, MEDIA_TYPE_1);
        assertEq(yes0, 0);
        assertEq(no0, 0);
        assertEq(localYes0, 0);
        assertEq(localNo0, 0);

        (
            uint256 mediaId1,
            string memory uri1,
            string memory desc1,
            string memory type1,
            uint256 yes1,
            uint256 no1,
            uint256 localYes1,
            uint256 localNo1
        ) = voting.getMediaItem(eventId, 1);

        assertEq(mediaId1, 1);
        assertEq(uri1, MEDIA_URI_2);
        assertEq(desc1, MEDIA_DESC_2);
        assertEq(type1, MEDIA_TYPE_2);
        assertEq(yes1, 0);
        assertEq(no1, 0);
        assertEq(localYes1, 0);
        assertEq(localNo1, 0);
    }

    function testAddMediaItemStoresCorrectData() public {
        uint256 eventId = _createDefaultEventWithNoMedia();

        uint256 mediaId = voting.addMediaItem(
            eventId,
            MEDIA_URI_1,
            MEDIA_DESC_1,
            MEDIA_TYPE_1
        );

        assertEq(mediaId, 0, "First mediaId should be 0");

        (
            uint256 storedMediaId,
            string memory storedUri,
            string memory storedDescription,
            string memory storedMediaType,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, mediaId);

        assertEq(storedMediaId, mediaId);
        assertEq(storedUri, MEDIA_URI_1);
        assertEq(storedDescription, MEDIA_DESC_1);
        assertEq(storedMediaType, MEDIA_TYPE_1);
        assertEq(yes, 0);
        assertEq(no, 0);
        assertEq(localYes, 0);
        assertEq(localNo, 0);

        assertEq(voting.getMediaCountForEvent(eventId), 1);
    }

    function testAddMediaItemEmitsMediaItemAdded() public {
        uint256 eventId = _createDefaultEventWithNoMedia();

        vm.expectEmit(true, true, false, true);
        emit MediaVoting.MediaItemAdded(
            eventId,
            0,
            MEDIA_URI_1,
            MEDIA_DESC_1,
            MEDIA_TYPE_1
        );

        voting.addMediaItem(
            eventId,
            MEDIA_URI_1,
            MEDIA_DESC_1,
            MEDIA_TYPE_1
        );
    }

    function testAddMediaItemRevertsForUnknownEvent() public {
        vm.expectRevert(bytes("Unknown event"));
        voting.addMediaItem(
            999,
            MEDIA_URI_1,
            MEDIA_DESC_1,
            MEDIA_TYPE_1
        );
    }

    function testVoteOnMediaGlobalYes() public {
        uint256 eventId = _createDefaultEventWithOneMedia();

        uint256 mediaId = 0;
        bytes32 voterHash = keccak256("voter-1");

        vm.expectEmit(true, true, true, true);
        emit MediaVoting.MediaVoted(
            eventId,
            mediaId,
            voterHash,
            true,
            false
        );

        voting.voteOnMedia(
            eventId,
            mediaId,
            voterHash,
            true,
            false
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, mediaId);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertEq(localYes, 0);
        assertEq(localNo, 0);

        assertTrue(voting.hasVotedOnMedia(eventId, mediaId, voterHash));
    }

    function testVoteOnMediaLocalYesCountsAsGlobalAndLocal() public {
        uint256 eventId = _createDefaultEventWithOneMedia();

        uint256 mediaId = 0;
        bytes32 voterHash = keccak256("voter-2");

        voting.voteOnMedia(
            eventId,
            mediaId,
            voterHash,
            true,
            true
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, mediaId);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertEq(localYes, 1);
        assertEq(localNo, 0);
    }

    function testVoteOnMediaLocalNoCountsAsGlobalAndLocal() public {
        uint256 eventId = _createDefaultEventWithOneMedia();

        uint256 mediaId = 0;
        bytes32 voterHash = keccak256("voter-3");

        voting.voteOnMedia(
            eventId,
            mediaId,
            voterHash,
            false,
            true
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, mediaId);

        assertEq(yes, 0);
        assertEq(no, 1);
        assertEq(localYes, 0);
        assertEq(localNo, 1);
    }

    function testVoteOnMediaRevertsForUnknownEvent() public {
        bytes32 voterHash = keccak256("voter-4");

        vm.expectRevert(bytes("Unknown event"));
        voting.voteOnMedia(
            999,
            0,
            voterHash,
            true,
            false
        );
    }

    function testVoteOnMediaRevertsForUnknownMedia() public {
        uint256 eventId = _createDefaultEventWithNoMedia();
        bytes32 voterHash = keccak256("voter-5");

        vm.expectRevert(bytes("Unknown media item"));
        voting.voteOnMedia(
            eventId,
            999,
            voterHash,
            true,
            false
        );
    }

    function testDoubleVoteReverts() public {
        uint256 eventId = _createDefaultEventWithOneMedia();

        uint256 mediaId = 0;
        bytes32 voterHash = keccak256("voter-6");

        voting.voteOnMedia(
            eventId,
            mediaId,
            voterHash,
            true,
            false
        );

        vm.expectRevert(bytes("Already voted for this media"));
        voting.voteOnMedia(
            eventId,
            mediaId,
            voterHash,
            false,
            false
        );
    }

    function testMultipleMediaItemsUnderOneEvent() public {
        uint256 eventId = _createDefaultEventWithNoMedia();

        uint256 mediaId1 = voting.addMediaItem(
            eventId,
            MEDIA_URI_1,
            MEDIA_DESC_1,
            MEDIA_TYPE_1
        );

        uint256 mediaId2 = voting.addMediaItem(
            eventId,
            MEDIA_URI_2,
            MEDIA_DESC_2,
            MEDIA_TYPE_2
        );

        assertEq(mediaId1, 0);
        assertEq(mediaId2, 1);
        assertEq(voting.getMediaCountForEvent(eventId), 2);
    }

    function testDifferentMediaHaveIndependentVotes() public {
        uint256 eventId = _createDefaultEventWithTwoMedia();

        bytes32 voterHash1 = keccak256("voter-7");
        bytes32 voterHash2 = keccak256("voter-8");

        voting.voteOnMedia(eventId, 0, voterHash1, true, false);
        voting.voteOnMedia(eventId, 1, voterHash2, false, false);

        (
            uint256 id1,
            string memory uri1,
            string memory desc1,
            string memory type1,
            uint256 yes1,
            uint256 no1,
            uint256 localYes1,
            uint256 localNo1
        ) = voting.getMediaItem(eventId, 0);

        (
            uint256 id2,
            string memory uri2,
            string memory desc2,
            string memory type2,
            uint256 yes2,
            uint256 no2,
            uint256 localYes2,
            uint256 localNo2
        ) = voting.getMediaItem(eventId, 1);

        id1; uri1; desc1; type1; localYes1; localNo1;
        id2; uri2; desc2; type2; localYes2; localNo2;

        assertEq(yes1, 1);
        assertEq(no1, 0);

        assertEq(yes2, 0);
        assertEq(no2, 1);
    }

    function testSameVoterCanVoteOnDifferentMediaItems() public {
        uint256 eventId = _createDefaultEventWithTwoMedia();

        bytes32 voterHash = keccak256("same-voter");

        voting.voteOnMedia(eventId, 0, voterHash, true, false);
        voting.voteOnMedia(eventId, 1, voterHash, false, false);

        assertTrue(voting.hasVotedOnMedia(eventId, 0, voterHash));
        assertTrue(voting.hasVotedOnMedia(eventId, 1, voterHash));
    }

    function testGetEventCountIncreasesCorrectly() public {
        MediaVoting.MediaInput[] memory inputs = _emptyMediaInputs();

        assertEq(voting.getEventCount(), 0);

        voting.createEvent(
            EVENT_NAME,
            EVENT_LOCATION,
            EVENT_TIMESTAMP,
            REPORTER_NAME,
            REPORTER_ORG,
            inputs
        );

        assertEq(voting.getEventCount(), 1);

        voting.createEvent(
            "Another event",
            "Kosice",
            EVENT_TIMESTAMP + 1,
            "Alice",
            "News Org",
            inputs
        );

        assertEq(voting.getEventCount(), 2);
    }

    function testOwnerCanSetZKVerifier() public {
        voting.setZKVerifier(address(mockVerifier));
        assertEq(address(voting.zkVerifier()), address(mockVerifier));
    }

    function testNonOwnerCannotSetZKVerifier() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(bytes("Not owner"));
        voting.setZKVerifier(address(mockVerifier));
    }

    function testOwnerCanSetZKMode() public {
        voting.setZKMode(true, true);

        assertEq(voting.zkVotingEnabled(), true);
        assertEq(voting.zkVCHashCheckEnabled(), true);
    }

    function testNonOwnerCannotSetZKMode() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(bytes("Not owner"));
        voting.setZKMode(true, true);
    }

    function testManualVoteRevertsWhenZKModeEnabled() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("manual-revert");

        _setupZKVerifierAndEnable(true, false);

        vm.expectRevert(bytes("Use proof-based voting"));
        voting.voteOnMedia(eventId, 0, voterHash, true, false);
    }

    function testVoteOnMediaWithProofRevertsWhenZKModeDisabled() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-disabled");

        vm.expectRevert(bytes("ZK voting disabled"));
        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofRevertsWhenVerifierNotSet() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("no-verifier");

        voting.setZKMode(true, false);

        vm.expectRevert(bytes("ZK verifier not set"));
        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofRevertsForInvalidVoteProof() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("invalid-vote-proof");

        _setupZKVerifierAndEnable(true, false);
        mockVerifier.setVoteValid(false);

        vm.expectRevert(bytes("Invalid vote zk proof"));
        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofRevertsForInvalidVCHashProof() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("invalid-vc-hash");

        _setupZKVerifierAndEnable(true, true);
        mockVerifier.setVoteValid(true);
        mockVerifier.setVCHashValid(false);

        vm.expectRevert(bytes("Invalid VC hash zk proof"));
        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofCountsGlobalYesForNonLocalVoter() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-non-local");

        _setupZKVerifierAndEnable(true, false);
        mockVerifier.setVoteValid(true);
        mockVerifier.setLocal(false);

        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, 0);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertEq(localYes, 0);
        assertEq(localNo, 0);
    }

    function testVoteOnMediaWithProofCountsGlobalAndLocalYesForLocalVoter() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-local-yes");

        _setupZKVerifierAndEnable(true, false);
        mockVerifier.setVoteValid(true);
        mockVerifier.setLocal(true);

        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, 0);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertEq(localYes, 1);
        assertEq(localNo, 0);
    }

    function testVoteOnMediaWithProofCountsGlobalAndLocalNoForLocalVoter() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-local-no");

        _setupZKVerifierAndEnable(true, false);
        mockVerifier.setVoteValid(true);
        mockVerifier.setLocal(true);

        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            false,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );

        (
            ,
            ,
            ,
            ,
            uint256 yes,
            uint256 no,
            uint256 localYes,
            uint256 localNo
        ) = voting.getMediaItem(eventId, 0);

        assertEq(yes, 0);
        assertEq(no, 1);
        assertEq(localYes, 0);
        assertEq(localNo, 1);
    }

    function testVoteOnMediaWithProofMarksVoterAsVoted() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-has-voted");

        _setupZKVerifierAndEnable(true, false);

        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );

        assertTrue(voting.hasVotedOnMedia(eventId, 0, voterHash));
    }

    function testVoteOnMediaWithProofDoubleVoteReverts() public {
        uint256 eventId = _createDefaultEventWithOneMedia();
        bytes32 voterHash = keccak256("zk-double-vote");

        _setupZKVerifierAndEnable(true, false);

        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );

        vm.expectRevert(bytes("Already voted for this media"));
        voting.voteOnMediaWithProof(
            eventId,
            0,
            voterHash,
            false,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofRevertsForUnknownEvent() public {
        bytes32 voterHash = keccak256("zk-unknown-event");

        _setupZKVerifierAndEnable(true, false);

        vm.expectRevert(bytes("Unknown event"));
        voting.voteOnMediaWithProof(
            999,
            0,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }

    function testVoteOnMediaWithProofRevertsForUnknownMedia() public {
        uint256 eventId = _createDefaultEventWithNoMedia();
        bytes32 voterHash = keccak256("zk-unknown-media");

        _setupZKVerifierAndEnable(true, false);

        vm.expectRevert(bytes("Unknown media item"));
        voting.voteOnMediaWithProof(
            eventId,
            999,
            voterHash,
            true,
            DUMMY_VOTE_PROOF,
            DUMMY_VC_HASH_PROOF
        );
    }
}