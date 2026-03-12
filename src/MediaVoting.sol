// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Media event voting with per-media VC-hash deduplication
/// @notice One NewsEvent aggregates multiple MediaItems (image + description),
///         and voting happens per MediaItem, not per NewsEvent.
contract MediaVoting {
   
    /// @dev One media item belonging to a news event.
    struct MediaItem {
        uint256 id; // Local media ID inside the event, equal to index in mediaItems array
        string uri;
        string description;
        string mediaType;

        // Vote counters integrated directly into MediaItem
        uint256 yesCount;
        uint256 noCount;
        uint256 localYesCount;
        uint256 localNoCount;

        // Deduplication per media item: hash(VC) => true/false
        mapping(bytes32 => bool) hasVoted;
    }

    /// @dev Core data for a news event.
    struct NewsEvent {
        uint256 id; // Global event ID, equal to index in newsEvents array
        string name;
        string location;
        uint64 timestamp;
        address reporter;
        string reporterName;
        string reporterOrg;

        // Each news event contains its own list of media items
        MediaItem[] mediaItems;
    }

    /// @dev Input struct used when creating an event with multiple media items.
    struct MediaInput {
        string uri;
        string description;
        string mediaType;
    }

    /// @dev List of all news events.
    NewsEvent[] private newsEvents;

    /// @dev Emitted when a new event is created.
     event EventCreated(
        uint256 indexed eventId,
        address indexed reporter,
        string name,
        string location,
        uint64 timestamp,
        string reporterName,
        string reporterOrg
    );

    /// @dev Emitted when a new media item is added under an event.
    event MediaItemAdded(
        uint256 indexed eventId,
        uint256 indexed mediaId,
        string uri,
        string description,
        string mediaType
    );

    /// @dev Emitted when a vote is cast on a media item.
    /// @param support true = upvote, false = downvote
    event MediaVoted(
        uint256 indexed eventId,
        uint256 indexed mediaId,
        bytes32 indexed voterHash,
        bool support,
        bool isLocalVoter
    );

    /// @notice Create a new event and optionally add multiple media items immediately.
    /// @dev eventId is equal to the index in the newsEvents array.
    /// @param name Title/name of the event.
    /// @param location City/village where the event happened.
    /// @param timestamp Unix timestamp (date + time combined).
    /// @param reporterName Name of the reporter.
    /// @param reporterOrg Organization of the reporter.
    function createEvent(
        string calldata name,
        string calldata location,
        uint64 timestamp,
        string calldata reporterName,
        string calldata reporterOrg,
        MediaInput[] calldata mediaInputs
    ) external returns (uint256 eventId) {
        eventId = newsEvents.length;

        newsEvents.push();
        NewsEvent storage e = newsEvents[eventId];

        e.id = eventId;
        e.name = name;
        e.location = location;
        e.timestamp = timestamp;
        e.reporter = msg.sender;
        e.reporterName = reporterName;
        e.reporterOrg = reporterOrg;

        emit EventCreated(
            eventId,
            msg.sender,
            name,
            location,
            timestamp,
            reporterName,
            reporterOrg
        );

        for (uint256 i = 0; i < mediaInputs.length; i++) {
            _addMediaItem(
                eventId,
                mediaInputs[i].uri,
                mediaInputs[i].description,
                mediaInputs[i].mediaType
            );
        }
    }

    /// @notice Add a media item to an existing news event.
    /// @dev mediaId is equal to the index in the mediaItems array of the given event.
    
   function addMediaItem(
        uint256 eventId,
        string calldata uri,
        string calldata description,
        string calldata mediaType
    ) external returns (uint256 mediaId) {
        require(eventId < newsEvents.length, "Unknown event");
        mediaId = _addMediaItem(eventId, uri, description, mediaType);
    }

    /// @dev Internal helper to append a media item into NewsEvent.mediaItems.
    function _addMediaItem(
        uint256 eventId,
        string calldata uri,
        string calldata description,
        string calldata mediaType
    ) internal returns (uint256 mediaId) {
        NewsEvent storage e = newsEvents[eventId];

        mediaId = e.mediaItems.length;

        e.mediaItems.push();
        MediaItem storage m = e.mediaItems[mediaId];

        m.id = mediaId;
        m.uri = uri;
        m.description = description;
        m.mediaType = mediaType;

        emit MediaItemAdded(eventId, mediaId, uri, description, mediaType);
    }

    /// @notice Vote on a specific media item inside a specific event.
    /// @param eventId Global event ID, equal to index in newsEvents array.
    /// @param mediaId Local media ID, equal to index in mediaItems array for the event.
    /// @param voterHash Hash derived from VC.
    /// @param support true = yes vote, false = no vote.
    /// @param isLocalVoter true if voter is local.
    function voteOnMedia(
        uint256 eventId,
        uint256 mediaId,
        bytes32 voterHash,
        bool support,
        bool isLocalVoter
    ) external {
        require(eventId < newsEvents.length, "Unknown event");

        NewsEvent storage e = newsEvents[eventId];
        require(mediaId < e.mediaItems.length, "Unknown media item");

        MediaItem storage m = e.mediaItems[mediaId];

        require(!m.hasVoted[voterHash], "Already voted for this media");
        m.hasVoted[voterHash] = true;

        if (support) {
            m.yesCount += 1;
            if (isLocalVoter) {
                m.localYesCount += 1;
            }
        } else {
            m.noCount += 1;
            if (isLocalVoter) {
                m.localNoCount += 1;
            }
        }

        emit MediaVoted(eventId, mediaId, voterHash, support, isLocalVoter);
    }

    /// @notice Check whether a voter has already voted on a specific media item.
    function hasVotedOnMedia(
        uint256 eventId,
        uint256 mediaId,
        bytes32 voterHash
    ) external view returns (bool) {
        require(eventId < newsEvents.length, "Unknown event");

        NewsEvent storage e = newsEvents[eventId];
        require(mediaId < e.mediaItems.length, "Unknown media item");

        return e.mediaItems[mediaId].hasVoted[voterHash];
    }

    /// @notice Get metadata of one event.
    function getEvent(uint256 eventId)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory location,
            uint64 timestamp,
            address reporter,
            string memory reporterName,
            string memory reporterOrg,
            uint256 mediaCount
        )
    {
        require(eventId < newsEvents.length, "Unknown event");

        NewsEvent storage e = newsEvents[eventId];

        return (
            e.id,
            e.name,
            e.location,
            e.timestamp,
            e.reporter,
            e.reporterName,
            e.reporterOrg,
            e.mediaItems.length
        );
    }

    /// @notice Get one media item from one event.
    function getMediaItem(uint256 eventId, uint256 mediaId)
        external
        view
        returns (
            uint256 id,
            string memory uri,
            string memory description,
            string memory mediaType,
            uint256 yesCount,
            uint256 noCount,
            uint256 localYesCount,
            uint256 localNoCount
        )
    {
        require(eventId < newsEvents.length, "Unknown event");

        NewsEvent storage e = newsEvents[eventId];
        require(mediaId < e.mediaItems.length, "Unknown media item");

        MediaItem storage m = e.mediaItems[mediaId];

        return (
            m.id,
            m.uri,
            m.description,
            m.mediaType,
            m.yesCount,
            m.noCount,
            m.localYesCount,
            m.localNoCount
        );
    }

    /// @notice Get number of all news events.
    function getEventCount() external view returns (uint256) {
        return newsEvents.length;
    }

    /// @notice Get number of media items for a given event.
    function getMediaCountForEvent(uint256 eventId) external view returns (uint256) {
        require(eventId < newsEvents.length, "Unknown event");
        return newsEvents[eventId].mediaItems.length;
    }
}