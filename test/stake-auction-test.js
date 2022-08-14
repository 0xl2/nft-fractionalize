const { expect } = require("chai");
const { ethers } = require("hardhat");

describe.only("Fraction contract Test", function () {
    before("Deploy contracts", async function () {
        const [owner, dev, alice, bob] = await ethers.getSigners();

        this.owner = owner;
        this.alice = alice;
        this.bob = bob;

        const FToken = await ethers.getContractFactory("FToken");
        this.fToken = await FToken.deploy("FractionToken", "FTX");
        await this.fToken.deployed();
        console.log(`FractionToken is deployed to: ${this.fToken.address}`);

        const FStake = await ethers.getContractFactory("FStake");
        this.fStake = await FStake.deploy(this.fToken.address);
        await this.fStake.deployed();
        console.log(`FStake is deployed to: ${this.fStake.address}`);

        const NFTAuction = await ethers.getContractFactory("NFTAuction");
        this.nftAuction = await NFTAuction.deploy(this.fToken.address, dev.address, this.fStake.address);
        await this.nftAuction.deployed();
        console.log(`NFTAuction deployed to: ${this.nftAuction.address}`);

        // set Auction address
        await this.fToken.setAuction(this.nftAuction.address);

        // mint FToken to alice and bob
        await this.fToken.connect(this.owner).mint(this.alice.address, ethers.utils.parseUnits('1000'));
        await this.fToken.connect(this.owner).mint(this.bob.address, ethers.utils.parseUnits('500'));
    });

    describe("Alice do staking first", function() {
        it("Alice do half staking before auction reward received", async function() {
            const tokenAmount = ethers.utils.parseUnits('500');

            // allow FToken first
            await this.fToken.connect(this.alice).approve(this.fStake.address, tokenAmount);

            // do staking
            await this.fStake.connect(this.alice).stake(tokenAmount);

            const totalStaked = await this.fStake.totalStakedAmount();
            expect(totalStaked).to.eq(tokenAmount);

            const aliceReward = await this.fStake.pendingReward(this.alice.address);
            expect(aliceReward).to.eq(0); // here zero as no reward
        });
    });

    describe("Create auction and testing", function() {
        it("Start auction", async function() {
            const startingBal = ethers.utils.parseEther('0.1');
            await this.nftAuction.connect(this.owner).start(
                startingBal, // 0.1ETH for starting bid
                5 * 60 // 5 min
            );

            const auctionInfo = await this.nftAuction.auctions(1);
            expect(auctionInfo.seller).to.eq(this.owner.address);
            expect(auctionInfo.winner).to.eq(ethers.constants.AddressZero);
            expect(auctionInfo.highestBid).to.eq(startingBal);
        });

        it("Do bidding", async function() {
            // bid with 0.1ETH will fail
            await expect(
                this.nftAuction.connect(this.alice).bid({value: ethers.utils.parseEther('0.1')})
            ).to.be.revertedWith("Amount is low")

            // alice bid with 0.2ETH
            let bidBal = ethers.utils.parseEther('0.2');
            await this.nftAuction.connect(this.alice).bid({value: bidBal});

            let auctionInfo = await this.nftAuction.auctions(1);
            expect(auctionInfo.winner).to.eq(this.alice.address);
            expect(auctionInfo.highestBid).to.eq(bidBal);

            // bob bid with 0.3 ETH
            bidBal = ethers.utils.parseEther('0.3');
            await this.nftAuction.connect(this.bob).bid({value: bidBal});

            auctionInfo = await this.nftAuction.auctions(1);
            expect(auctionInfo.winner).to.eq(this.bob.address);
            expect(auctionInfo.highestBid).to.eq(bidBal);
            
            // alice bid with 0.15ETH
            bidBal = ethers.utils.parseEther('0.15');
            await this.nftAuction.connect(this.alice).bid({value: bidBal});

            auctionInfo = await this.nftAuction.auctions(1);
            expect(auctionInfo.winner).to.eq(this.alice.address);
            expect(auctionInfo.highestBid).to.eq(ethers.utils.parseEther('0.35'));
        });

        it("Complete the auction", async function() {
            await this.nftAuction.connect(this.owner).end();

            const auctionInfo = await this.nftAuction.auctions(1);
            expect(auctionInfo.seller).to.eq(this.owner.address);
            expect(auctionInfo.winner).to.eq(this.alice.address);
            expect(auctionInfo.highestBid).to.eq(ethers.utils.parseEther('0.35'));
        });
    });

    describe("Testing FToken Staking", function() {
        it("Alice do staking", async function() {
            const tokenAmount = ethers.utils.parseUnits('500');

            // allow FToken first
            await this.fToken.connect(this.alice).approve(this.fStake.address, tokenAmount);

            // do staking
            await this.fStake.connect(this.alice).stake(tokenAmount);

            const totalStaked = await this.fStake.totalStakedAmount();
            expect(totalStaked).to.eq(ethers.utils.parseUnits('1000'));

            const aliceReward = await this.fStake.pendingReward(this.alice.address);
            expect(aliceReward).to.be.gt(0);
        });

        it("Bob do staking", async function() {
            const tokenAmount = ethers.utils.parseUnits('500');

            // allow FToken first
            await this.fToken.connect(this.bob).approve(this.fStake.address, tokenAmount);

            // do staking
            await this.fStake.connect(this.bob).stake(tokenAmount);

            const totalStaked = await this.fStake.totalStakedAmount();
            expect(totalStaked).to.eq(ethers.utils.parseUnits('1500'));

            const bobReward = await this.fStake.pendingReward(this.bob.address);
            expect(bobReward).to.eq(0); // zero as he staked after reward received
        });

        it("Testing pending reward and withdraw", async function() {
            await expect(
                this.fStake.connect(this.bob).withdrawReward()
            ).to.be.revertedWith("No reward");

            await this.fStake.connect(this.alice).withdrawReward();
        });
    });
});