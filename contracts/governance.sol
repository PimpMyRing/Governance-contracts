// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DaoMemberShip} from "./daoMemberShip.sol";
import {LSAGVerifier} from "./lsag-verifier.sol";

contract RingDao {
    DaoMemberShip memberShipNft;

    uint256 public proposalCount = 0;
    uint256 public constant VOTE_DURATION = 7 days;
    uint256 public constant MIN_VOTERS = 5;
    uint256 public constant MIN_ACCEPTANCE_RATIO = 70; // if 100 * approved / total > MIN_ACCEPTANCE_RATIO, then proposal is approved

    struct Proposal {
        string description;
        uint256 voteForCount;
        uint256 voteAgainstCount;
        bool executed;
        uint256 startTime;
        address target;
        uint256 value;
        bytes callData;
    }

    // proposal id => proposal
    mapping(uint256 => Proposal) public proposals;
    // proposal id => voted
    mapping(uint256 => mapping(address => bool)) public voted;

    constructor() {
        memberShipNft = new DaoMemberShip();

        // deployer is the first member
        DaoMemberShip(memberShipNft).mint();
    }

    function newProposal(
        string memory _description,
        address target,
        uint256 value,
        bytes memory callData
    ) public {
        // which data ? full proposal, ipfs uri or only new bytecode hash?
        // only member can create proposal
        require(
            memberShipNft.balanceOf(msg.sender) > 0,
            "only member can create proposal"
        );

        // create proposal
        proposals[proposalCount] = Proposal({
            description: _description,
            voteForCount: 0,
            voteAgainstCount: 0,
            executed: false,
            startTime: block.timestamp,
            target: target,
            value: value,
            callData: callData
        });
    }

    function anonProposal(
        string memory _description,
        address target,
        uint256 value,
        bytes memory callData,
        uint256[] memory ring,
        uint256[] memory responses,
        uint256 c, // signature seed
        uint256[2] memory keyImage,
        string memory linkabilityFlag,
        uint256[] memory witnesses
    ) public {
        uint256 message = uint256(keccak256(abi.encodePacked(_description, target, value, calldata)));
        // require all the ring members to be part of the dao
        for (uint256 i = 0; i < ring.length; i += 2) {
            require(
                memberShipNft.balanceOf(
                    LSAGVerifier.pointToAddress([ring[i], ring[i + 1]])
                ) > 0,
                "all ring members should be part of the dao"
            );
        }
        // only member can create proposal
        require(
            LSAGVerifier.verify(
                message,
                ring,
                responses,
                c,
                keyImage,
                linkabilityFlag,
                witnesses
            ),
            "only member can create proposal"
        );

        // create proposal
        proposals[proposalCount] = Proposal({
            description: _description,
            voteForCount: 0,
            voteAgainstCount: 0,
            executed: false,
            startTime: block.timestamp,
            target: target,
            value: value,
            callData: callData
        });
    }

    function voteTrue(
        uint256 _proposalId,
        uint256[] memory ring,
        uint256[] memory responses,
        uint256 c, // signature seed
        uint256[2] memory keyImage,
        string memory linkabilityFlag,
        uint256[] memory witnesses
    ) public {
        // require all the ring members to be part of the dao
        for (uint256 i = 0; i < ring.length; i += 2) {
            require(
                memberShipNft.balanceOf(
                    LSAGVerifier.pointToAddress([ring[i], ring[i + 1]])
                ) > 0,
                "all ring members should be part of the dao"
            );
        }
        uint256 message = uint256(keccak256(abi.encodePacked(_proposalId)));
        // check if proposal is still open
        require(
            block.timestamp < proposals[_proposalId].startTime + VOTE_DURATION,
            "proposal is closed"
        );

        // only member can vote
        require(
            LSAGVerifier.verify(
                message,
                ring,
                responses,
                c,
                keyImage,
                linkabilityFlag,
                witnesses
            ),
            "only member can vote"
        );

        // check if member has already voted
        address member = LSAGVerifier.pointToAddress(keyImage);
        require(!voted[_proposalId][member], "member has already voted");

        // vote
        proposals[_proposalId].voteForCount++;

        // mark keyImage as voted
        voted[_proposalId][member] = true;
    }

    function voteFalse(
        uint256 _proposalId,
        uint256[] memory ring,
        uint256[] memory responses,
        uint256 c, // signature seed
        uint256[2] memory keyImage,
        string memory linkabilityFlag,
        uint256[] memory witnesses
    ) public {
        // require all the ring members to be part of the dao
        for (uint256 i = 0; i < ring.length; i += 2) {
            require(
                memberShipNft.balanceOf(
                    LSAGVerifier.pointToAddress([ring[i], ring[i + 1]])
                ) > 0,
                "all ring members should be part of the dao"
            );
        }
        uint256 message = uint256(keccak256(abi.encodePacked(_proposalId)));
        // check if proposal is still open
        require(
            block.timestamp < proposals[_proposalId].startTime + VOTE_DURATION,
            "proposal is closed"
        );

        // only member can vote
        require(
            LSAGVerifier.verify(
                message,
                ring,
                responses,
                c,
                keyImage,
                linkabilityFlag,
                witnesses
            ),
            "only member can vote"
        );

        // check if member has already voted
        address member = LSAGVerifier.pointToAddress(keyImage);
        require(!voted[_proposalId][member], "member has already voted");

        // vote
        proposals[_proposalId].voteAgainstCount++;

        // mark keyImage as voted
        voted[_proposalId][member] = true;
    }

    function executeProposal(uint256 _proposalId) public {
        // check if proposal is still open
        require(
            block.timestamp > proposals[_proposalId].startTime + VOTE_DURATION,
            "proposal is still open"
        );

        // check if proposal is not executed
        require(
            !proposals[_proposalId].executed,
            "proposal is already executed"
        );

        // check if proposal is approved
        require(
            (proposals[_proposalId].voteForCount * 100) /
                (proposals[_proposalId].voteForCount +
                    proposals[_proposalId].voteAgainstCount) >
                MIN_ACCEPTANCE_RATIO,
            "proposal is not approved"
        );

        // execute proposal
        proposals[_proposalId].executed = true;


        (bool success, ) = proposals[_proposalId].target.call{value: proposals[_proposalId].value}(proposals[_proposalId].callData);
    }
}
