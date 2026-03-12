# MediaVoting

MediaVoting is a Solidity smart contract for decentralized reporting of real-world news events and community voting on the credibility of attached media.

Each **NewsEvent** can contain multiple **MediaItems** (images, videos, etc.). Users can vote on the credibility of each media item individually. Voting is deduplicated using hashes derived from **Verifiable Credentials (VCs)**.

## Features

- Create news events with metadata (location, timestamp, reporter information)
- Attach multiple media items to each event
- Vote on credibility of individual media items
- Prevent double voting using VC-based hash deduplication
- Track both global votes and local votes (from the event location)

## Smart Contract Structure

```
NewsEvent
 ├── metadata (name, location, timestamp)
 ├── reporter info
 └── MediaItem[]
        ├── uri
        ├── description
        ├── mediaType
        └── votes
```

Each `MediaItem` stores:

- global **yes / no** votes
- **local votes** (votes from the event location)
- `mapping(bytes32 => bool)` to prevent duplicate votes

## Project Structure

```
src/        Solidity smart contracts
test/       Foundry tests
script/     Deployment scripts
lib/        Dependencies
```

## Requirements

This project uses **Foundry**.

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Build

```bash
forge build
```

## Run Tests

```bash
forge test
```

## Example Workflow

1. Create a news event
2. Attach media items to the event
3. Community members vote on credibility of each media item
4. The smart contract stores the voting results

## Future Improvements

- zkSNARK verification for local voters
- integration with Verifiable Credentials
- frontend interface
- deployment scripts