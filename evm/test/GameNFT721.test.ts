import { expect } from "chai";
import { ethers } from "hardhat";
import { GameNFT721 } from "../typechain-types";

describe("GameNFT721", function () {
  let nft: GameNFT721;
  let owner: any;
  let player: any;

  beforeEach(async function () {
    [owner, player] = await ethers.getSigners();

    const GameNFT721Factory = await ethers.getContractFactory("GameNFT721");
    nft = await GameNFT721Factory.deploy(
      "GameNFT",
      "GNFT",
      10000,                                  // maxSupply
      ethers.parseEther("0.01"),              // mintPrice
      "ipfs://placeholder/",                  // placeholderURI
      owner.address,                          // royaltyReceiver
      500                                     // 5% royalty
    );
    await nft.waitForDeployment();
  });

  it("should deploy with correct params", async function () {
    expect(await nft.name()).to.equal("GameNFT");
    expect(await nft.symbol()).to.equal("GNFT");
    expect(await nft.maxSupply()).to.equal(10000);
  });

  it("should mint an NFT to a recipient", async function () {
    const tx = await nft.mint(player.address);
    await tx.wait();
    expect(await nft.ownerOf(1)).to.equal(player.address);
    expect(await nft.totalSupply()).to.equal(1);
  });

  it("should return placeholder URI before reveal", async function () {
    await nft.mint(player.address);
    expect(await nft.tokenURI(1)).to.equal("ipfs://placeholder/");
  });

  it("should return real URI after reveal", async function () {
    await nft.mint(player.address);
    await nft.reveal("ipfs://real-metadata/");
    expect(await nft.tokenURI(1)).to.equal("ipfs://real-metadata/1.json");
  });

  it("should enforce max supply", async function () {
    const SmallNFT = await ethers.getContractFactory("GameNFT721");
    const smallNft = await SmallNFT.deploy("S", "S", 1, 0, "", owner.address, 0);
    await smallNft.mint(player.address);
    await expect(smallNft.mint(player.address)).to.be.revertedWith("Max supply reached");
  });

  it("should support ERC2981 royalty interface", async function () {
    expect(await nft.supportsInterface("0x2a55205a")).to.be.true; // ERC2981
  });
});
