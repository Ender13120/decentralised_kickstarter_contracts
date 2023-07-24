import { ethers } from "hardhat";
import { expect } from "chai";

describe("Campaign", function () {
  async function deployCampaignFixture() {
    const [owner, investor1, investor2, campaignOwner] =
      await ethers.getSigners();

    const Campaign = await ethers.getContractFactory("Campaign");
    const campaign = await Campaign.deploy();

    return { campaign, owner, investor1, investor2, campaignOwner };
  }

  describe("Investment", function () {
    it("Should allow investors to invest", async function () {
      const { campaign, campaignOwner, investor1 } =
        await deployCampaignFixture();
      const milestoneDescriptions = ["Milestone 1", "Milestone 2"];
      const milestonePercentages = [20, 80];
      const testCampaign = await campaign
        .connect(campaignOwner)
        .createCampaign(
          "Test Campaign",
          "This is a test campaign",
          1000,
          Math.floor(Date.now() / 1000) + 24 * 60 * 60,
          milestoneDescriptions,
          milestonePercentages
        );

      const investmentAmount = ethers.utils.parseEther("1");
      await campaign
        .connect(investor1)
        .investIntoCampaign(1, { value: investmentAmount });

      const investorBalance = await campaign.getInvestorBalance(
        1,
        investor1.address
      );
      expect(investorBalance).to.equal(investmentAmount);
    });
  });

  describe("Milestones", function () {
    it("Should allow owner to start a milestone vote", async function () {
      const { campaign, campaignOwner, investor1 } =
        await deployCampaignFixture();
      const milestoneDescriptions = ["Milestone 1", "Milestone 2"];
      const milestonePercentages = [20, 80];
      const testCampaign = await campaign
        .connect(campaignOwner)
        .createCampaign(
          "Test Campaign",
          "This is a test campaign",
          1000,
          Math.floor(Date.now() / 1000) + 24 * 60 * 60,
          milestoneDescriptions,
          milestonePercentages
        );

      await campaign
        .connect(campaignOwner)
        .startMilestoneVoteAsCampaignOwner(1, 0);

      const milestoneVote = await campaign.getMilestoneVoteDetails(
        1,
        0
      );
      expect(milestoneVote.startDate).not.to.equal(0);
    });
    // Additional tests for claiming milestones, voting, etc.
  });

  describe("Dissolution", function () {
    it("Should allow owner to start dissolution vote", async function () {
      const { campaign, campaignOwner, investor1 } =
        await deployCampaignFixture();
      const milestoneDescriptions = ["Milestone 1", "Milestone 2"];
      const milestonePercentages = [20, 80];
      const testCampaign = await campaign
        .connect(campaignOwner)
        .createCampaign(
          "Test Campaign",
          "This is a test campaign",
          1000,
          Math.floor(Date.now() / 1000) + 24 * 60 * 60,
          milestoneDescriptions,
          milestonePercentages
        );

      await campaign.connect(campaignOwner).dissolveCampaignVote(1);

      const dissolutionVote =
        await campaign.getDissolutionVoteDetails(1);
      expect(dissolutionVote.startDate).not.to.equal(0);
    });

    // Additional tests for claiming dissolution, voting, etc.
  });

  // Additional tests for refund, comments, etc.
});
