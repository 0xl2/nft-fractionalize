const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Fraction contract Test", function () {
    let fToken, fStake, nftAuction, nftStore, nftFraction, testNFT;

    before("Deploy contract", async function () {
        const [owner, dev, alice] = await ethers.getSigners();

        const FToken = await ethers.getContractFactory("FToken");
        fToken = await FToken.deploy("FractionToken", "FTX");
        await fToken.deployed();
        console.log(`FractionToken is deployed to: ${fToken.address}`);

        const FStake = await ethers.getContractFactory("FStake");
        fStake = await FStake.deploy(fToken.address);
        await fStake.deployed();
        console.log(`FStake is deployed to: ${fStake.address}`);

        const NFTAuction = await ethers.getContractFactory("NFTAuction");
        nftAuction = await NFTAuction.deploy(fToken.address, dev.address, fStake.address);
        await nftAuction.deployed();
        console.log(`NFTAuction deployed to: ${nftAuction.address}`);

        const NFTStore = await ethers.getContractFactory("NFTStore");
        nftStore = await NFTStore.deploy();
        await nftStore.deployed();
        console.log(`NFTStore is deployed to: ${nftStore.address}`);

        const NFTFraction = await ethers.getContractFactory("NFTFraction");
        nftFraction = await NFTFraction.deploy(nftStore.address);
        await nftFraction.deployed();
        console.log(`NFTFraction is deployed to: ${nftFraction.address}`);

        const TestNFT = await ethers.getContractFactory("TestNFT");
        testNFT = await TestNFT.deploy();
        await testNFT.deployed();
        console.log(`TestNFT deployed to: ${testNFT.address}`);
    });

    it("NFTFraction test", async function() {
        
    });
});