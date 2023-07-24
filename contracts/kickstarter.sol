pragma solidity >=0.8.0 <0.9.0;

contract Campaign {
    struct Milestone {
        string description;
        uint percentage;
        uint milestoneAmount;
        bool completed;
        Vote vote;
    }

    struct CampaignData {
        string name;
        string description;
        Milestone[] milestones;
        uint raisedAmount;
        uint minimumCampaignGoal;
        uint currentMilestone;
        uint campaignEndDate;
        address payable campaignOwner;
        mapping(address => uint) investors;
        string[] comments;
        uint failedVoteCount; // Count of failed votes
        bool isActive;
    }

    struct Vote {
        uint startDate;
        uint yesVotes;
        uint noVotes;
        mapping(address => bool) voted;
    }

    mapping(uint => CampaignData) public campaigns;
    mapping(address => uint[]) public campaignsByOwner;
    mapping(uint => uint) totalRaisedAmount;
    mapping(uint => Vote) dissolutionVotes;
    uint public campaignIdCounter;

    event CampaignFailed(uint campaignId);

    function createCampaign(
        string memory _name,
        string memory _description,
        uint _minCampaignGoal,
        uint _endDate,
        string[] memory _milestoneDescriptions,
        uint[] memory _milestonePercentages
    ) public {
        require(
            _milestoneDescriptions.length == _milestonePercentages.length,
            "Milestone descriptions and percentages mismatch"
        );

        require(block.timestamp < _endDate, "End date must be in the future");

        // Check that sum of milestone percentages does not exceed 100%
        uint percentageSum = 0;
        for (uint i = 0; i < _milestonePercentages.length; i++) {
            percentageSum += _milestonePercentages[i];
        }

        campaignIdCounter++;
        CampaignData storage newCampaign = campaigns[campaignIdCounter];
        newCampaign.name = _name;
        newCampaign.description = _description;
        newCampaign.minimumCampaignGoal = _minCampaignGoal;
        newCampaign.campaignEndDate = _endDate;
        newCampaign.campaignOwner = payable(msg.sender);
        newCampaign.isActive = true;

        for (uint i = 0; i < _milestoneDescriptions.length; i++) {
            uint milestoneAmount = (_milestonePercentages[i] *
                _minCampaignGoal) / 100; // calculate amount of this milestone

            // Extend the size of the array
            newCampaign.milestones.push();

            // Initialize the new milestone directly in the storage array
            Milestone storage newMilestone = newCampaign.milestones[
                newCampaign.milestones.length - 1
            ];
            newMilestone.description = _milestoneDescriptions[i];
            newMilestone.percentage = _milestonePercentages[i];
            newMilestone.milestoneAmount = milestoneAmount;
            newMilestone.completed = false;
        }

        campaignsByOwner[msg.sender].push(campaignIdCounter);
    }

    function investIntoCampaign(uint _campaignId) public payable {
        CampaignData storage campaign = campaigns[_campaignId];
        require(campaign.isActive, "Campaign is not active");
        require(
            campaign.campaignEndDate >= block.timestamp,
            "Campaign already ended"
        );
        campaign.raisedAmount += msg.value;
        campaign.investors[msg.sender] += msg.value;

        totalRaisedAmount[_campaignId] += msg.value;
    }

    function startMilestoneVoteAsCampaignOwner(
        uint _campaignId,
        uint _milestoneIndex
    ) public {
        CampaignData storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Not authorized");
        require(
            campaign.currentMilestone == _milestoneIndex,
            "Invalid milestone index"
        );
        require(
            !campaign.milestones[_milestoneIndex].completed,
            "Milestone already completed"
        );

        // start a vote
        campaign.milestones[_milestoneIndex].vote.startDate = block.timestamp;
    }

    function claimMilestoneAsOwner(
        uint _campaignId,
        uint _milestoneIndex
    ) public {
        CampaignData storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Not authorized");
        require(
            campaign.currentMilestone == _milestoneIndex,
            "Invalid milestone index"
        );
        Milestone storage milestone = campaign.milestones[_milestoneIndex];
        require(!milestone.completed, "Milestone already completed");
        require(milestone.vote.startDate > 0, "Voting has not started");
        require(
            block.timestamp > milestone.vote.startDate + 7 days,
            "Voting period has not ended"
        );

        // if the majority voted 'yes', mark the milestone as completed and pay out
        if (milestone.vote.yesVotes > milestone.vote.noVotes) {
            milestone.completed = true;
            uint payoutAmount = milestone.milestoneAmount;

            // if this is the last milestone, payout all remaining funds
            if (_milestoneIndex == campaign.milestones.length - 1) {
                payoutAmount = campaign.raisedAmount;
            }

            campaign.campaignOwner.transfer(payoutAmount);
            campaign.raisedAmount -= payoutAmount;
            campaign.failedVoteCount = 0;
        } else {
            // if the vote failed, increment the failedVoteCount
            campaign.failedVoteCount++;

            // if there have been 3 failed votes, cancel the campaign
            if (campaign.failedVoteCount >= 3) {
                campaign.isActive = false;
                emit CampaignFailed(_campaignId);
            }
        }
    }

    function withdrawRefund(uint _campaignId) public {
        CampaignData storage campaign = campaigns[_campaignId];
        require(!campaign.isActive, "Campaign is still active");
        require(campaign.investors[msg.sender] > 0, "No investment found");

        uint totalRaisedBeforeRefunds = totalRaisedAmount[_campaignId];
        uint investment = campaign.investors[msg.sender];

        uint refundAmount = (campaign.raisedAmount * investment) /
            totalRaisedBeforeRefunds;

        // Safeguard to prevent re-entrancy attacks
        campaign.investors[msg.sender] = 0;
        campaign.raisedAmount -= refundAmount;

        // transfer the funds back to the investor
        payable(msg.sender).transfer(refundAmount);
    }

    function voteForMilestone(
        uint _campaignId,
        uint _milestoneIndex,
        bool _vote
    ) public {
        CampaignData storage campaign = campaigns[_campaignId];
        Milestone storage milestone = campaign.milestones[_milestoneIndex];
        require(milestone.vote.startDate > 0, "Voting has not started");
        require(
            block.timestamp <= milestone.vote.startDate + 7 days,
            "Voting period has ended"
        );
        require(!milestone.vote.voted[msg.sender], "You have already voted");
        require(
            campaign.investors[msg.sender] > 0,
            "You must be an investor to vote"
        );

        // record the vote
        if (_vote) {
            milestone.vote.yesVotes += campaign.investors[msg.sender];
        } else {
            milestone.vote.noVotes += campaign.investors[msg.sender];
        }
        milestone.vote.voted[msg.sender] = true;
    }

    function dissolveCampaignVote(uint _campaignId) public {
        CampaignData storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Not authorized");

        // Check that a dissolution vote has not already been started
        require(
            dissolutionVotes[_campaignId].startDate == 0,
            "Vote already initiated"
        );

        dissolutionVotes[_campaignId].startDate = block.timestamp;
    }

    function claimDissolutionAsOwner(uint _campaignId) public {
        CampaignData storage campaign = campaigns[_campaignId];

        Vote storage vote = dissolutionVotes[_campaignId];
        require(vote.startDate > 0, "No vote initiated");
        require(
            block.timestamp > vote.startDate + 7 days,
            "Voting period has not ended"
        );

        // Calculate the total votes (yes and no) as a percentage of the total invested amount
        uint totalVotes = vote.yesVotes + vote.noVotes;
        uint totalInvested = totalRaisedAmount[_campaignId];
        uint votePercentage = (totalVotes * 100) / totalInvested;

        // Ensure that total votes constitute at least 60% of the total invested amount
        require(votePercentage >= 60, "Not enough voters participated");

        if (vote.yesVotes > vote.noVotes) {
            campaign.isActive = false;
            emit CampaignFailed(_campaignId);
        } else {
            // Voting failed, reset the vote
            delete dissolutionVotes[_campaignId];
        }
    }

    function addCommentToCampaignAsOwner(
        uint _campaignId,
        string memory _comment
    ) public {
        CampaignData storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Not authorized");
        campaign.comments.push(_comment);
    }

    function getCampaign(
        uint _campaignId
    )
        public
        view
        returns (string memory, string memory, uint, uint, uint, uint)
    {
        CampaignData storage campaign = campaigns[_campaignId];
        return (
            campaign.name,
            campaign.description,
            campaign.raisedAmount,
            campaign.minimumCampaignGoal,
            campaign.currentMilestone,
            campaign.campaignEndDate
        );
    }

    function getComment(
        uint _campaignId,
        uint _commentIndex
    ) public view returns (string memory) {
        CampaignData storage campaign = campaigns[_campaignId];
        return campaign.comments[_commentIndex];
    }

    function getInvestorBalance(
        uint _campaignId,
        address _investor
    ) public view returns (uint) {
        return campaigns[_campaignId].investors[_investor];
    }

    function hasVotedInDissolutionVote(
        uint _campaignId,
        address _voter
    ) public view returns (bool) {
        return dissolutionVotes[_campaignId].voted[_voter];
    }

    function getDissolutionVoteDetails(
        uint _campaignId
    ) public view returns (uint startDate, uint yesVotes, uint noVotes) {
        return (
            dissolutionVotes[_campaignId].startDate,
            dissolutionVotes[_campaignId].yesVotes,
            dissolutionVotes[_campaignId].noVotes
        );
    }

    function getMilestone(
        uint _campaignId,
        uint _milestoneIndex
    ) external view returns (string memory, uint, bool) {
        CampaignData storage campaign = campaigns[_campaignId];
        Milestone storage milestone = campaign.milestones[_milestoneIndex];
        return (
            milestone.description,
            milestone.percentage,
            milestone.completed
        );
    }

    function getMilestoneDetails(
        uint _campaignId,
        uint _milestoneIndex
    )
        public
        view
        returns (
            string memory description,
            uint percentage,
            uint milestoneAmount,
            bool completed
        )
    {
        CampaignData storage campaign = campaigns[_campaignId];
        Milestone storage milestone = campaign.milestones[_milestoneIndex];
        return (
            milestone.description,
            milestone.percentage,
            milestone.milestoneAmount,
            milestone.completed
        );
    }

    function getMilestoneVoteDetails(
        uint _campaignId,
        uint _milestoneIndex
    ) public view returns (uint startDate, uint yesVotes, uint noVotes) {
        CampaignData storage campaign = campaigns[_campaignId];
        return (
            campaign.milestones[_milestoneIndex].vote.startDate,
            campaign.milestones[_milestoneIndex].vote.yesVotes,
            campaign.milestones[_milestoneIndex].vote.noVotes
        );
    }

    //placeholder for subgraph
    function getCampaignsByInvestor(
        address _investor
    ) public view returns (uint[] memory) {
        uint[] memory result = new uint[](campaignIdCounter);
        uint counter = 0;
        for (uint i = 1; i <= campaignIdCounter; i++) {
            if (campaigns[i].investors[_investor] > 0) {
                result[counter] = i;
                counter++;
            }
        }
        // Shrink size to fit the actual count
        uint[] memory fittedResult = new uint[](counter);
        for (uint j = 0; j < counter; j++) {
            fittedResult[j] = result[j];
        }
        return fittedResult;
    }
}
