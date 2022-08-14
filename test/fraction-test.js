const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Fraction contract Test", function () {
    before("Deploy contracts", async function () {
        const [owner, dev, alice, bob] = await ethers.getSigners();

        this.owner = owner;
        this.alice = alice;
        this.bob = bob;

        const FToken = await ethers.getContractFactory("FToken");
        this.fToken = await FToken.deploy("FractionToken", "FTX");
        await this.fToken.deployed();
        console.log(`FractionToken is deployed to: ${this.fToken.address}`);

        const NFTStore = await ethers.getContractFactory("NFTStore");
        this.nftStore = await NFTStore.deploy();
        await this.nftStore.deployed();
        console.log(`NFTStore is deployed to: ${this.nftStore.address}`);

        const NFTFraction = await ethers.getContractFactory("NFTFraction");
        this.nftFraction = await NFTFraction.deploy(this.nftStore.address);
        await this.nftFraction.deployed();
        console.log(`NFTFraction is deployed to: ${this.nftFraction.address}`);

        // deploy TestNFT contract
        const TestNFT = await ethers.getContractFactory("TestNFT");
        this.testNFT = await TestNFT.deploy();
        await this.testNFT.deployed();
        console.log(`TestNFT deployed to: ${this.testNFT.address}`);

        // mint TestNFT to users
        await this.testNFT.connect(this.alice).mint();
        await this.testNFT.connect(this.alice).mint();

        await this.testNFT.connect(this.bob).mint();

        // transfer ownership of FToken
        await this.fToken.connect(this.owner).transferOwnership(this.nftFraction.address);

        // set NFTFraction on NFTStore
        await this.nftStore.connect(owner).setFraction(this.nftFraction.address);
    });

    describe("Create Vault for TestNFT in NFTStore", function() {
        it("Create Vault can be called by only owner", async function() {
            const tokenBalance = ethers.utils.parseEther("100");

            await expect(
                this.nftStore.connect(this.alice).addNewVault(
                    this.fToken.address,
                    this.testNFT.address,
                    tokenBalance
                )
            ).to.be.revertedWith("Ownable: caller is not the owner");

            await expect(
                this.nftStore.connect(this.bob).addNewVault(
                    this.fToken.address,
                    this.testNFT.address,
                    tokenBalance
                )
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Create New Vault with Owner", async function() {
            // create 1st vault
            const tokenBalance = ethers.utils.parseEther("100");

            await this.nftStore.connect(this.owner).addNewVault(
                this.fToken.address,
                this.testNFT.address,
                tokenBalance
            );
            
            let vaultCnt = await this.nftStore.vaultCnt();
            expect(vaultCnt).to.eq(1);
            
            // create 2nd vault
            const tokenBalance1 = ethers.utils.parseEther("1000");

            await this.nftStore.connect(this.owner).addNewVault(
                this.fToken.address,
                this.testNFT.address,
                tokenBalance1
            );
            
            vaultCnt = await this.nftStore.vaultCnt();
            expect(vaultCnt).to.eq(2);
        })
    });

    describe("Test NFT Fractinalize", function() {
        it("Test Alice's NFT", async function() {
            // Cant make request with other's NFT
            await expect(
                this.nftFraction.connect(this.bob).requestMint(
                    1, // VaultID
                    [1] // tokenIds
                )
            ).to.be.revertedWith("ERC721: caller is not token owner nor approved")

            // approve NFTs first
            await this.testNFT.connect(this.alice).approve(
                this.nftFraction.address,
                1
            );

            await this.testNFT.connect(this.alice).approve(
                this.nftFraction.address,
                2
            );

            await this.nftFraction.connect(this.alice).requestMint(
                1, // VaultID
                [1] // tokenIds
            );

            await this.nftFraction.connect(this.alice).requestMint(
                2, // VaultID
                [2] // tokenIds
            );
        });

        it("Test Bob's NFT", async function() {
            // approve NFTs first
            await this.testNFT.connect(this.bob).approve(
                this.nftFraction.address,
                3
            );

            await this.nftFraction.connect(this.bob).requestMint(
                1, // VaultID
                [3] // tokenIds
            );
        });

        it("Checking minting FractionToken minting", async function() {
            await this.nftFraction.connect(this.alice).approveMintRequest(
                1, // VaultID
                [1] // tokenIds
            );

            const aliceBalance = await this.fToken.balanceOf(this.alice.address);
            expect(aliceBalance).to.eq(ethers.utils.parseUnits('1'));
        });
    });
});