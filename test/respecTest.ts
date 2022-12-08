import { ethers } from "hardhat";
import { expect } from "chai";
import { AavegotchiGameFacet, AavegotchiFacet, ItemsFacet } from "../typechain";
import { upgrade } from "../scripts/upgrades/upgrade-respec";
import { maticDiamondAddress } from "../scripts/helperFunctions";
import { Signer } from "@ethersproject/abstract-signer";

// how to run test
// npx hardhat test test/respecTest.ts
// todo: complete test

// i need itemsFacet for useConsumables(...)
// i need AavegotchiGameFacet for getting a gotchis claim time
// i need AavegotchiFacet for getting a gotchis skill points

describe("Testing Respec Potion", async function () {
  this.timeout(200000000);
  const diamondAddress = maticDiamondAddress;
  let aavegotchiGameFacet: AavegotchiGameFacet;
  let aavegotchiFacet: AavegotchiFacet;
  let itemsFacet: ItemsFacet;
  let signer: Signer;

  // these gotchis must have points already spent or available for this to be a valid test
  const gotchiIds = [
    6908, 15560, 22324, 16559, 5205, 9369, 22197, 13996, 11663, 15243,
  ];

  const availableSkillPointsBeforeUpgrade: number[] = [];
  const availableSkillPointsAfterUpgrade: number[] = [];
  const availableSkillPointsAfterSpend: number[] = [];
  const availableSkillPointsAfterRespec: number[] = [];
  const ages: number[] = [];
  const fibSequence = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];
  const oneMillionBlocks = 2300000;
  const aavegotchis: any[] = [];

  signer = await ethers.getSigner(maticDiamondAddress);

  const calcAgeSkillPoints = (age: number) => {
    let skillPoints = 0;
    for (let i = 0; i < fibSequence.length; i++) {
      if (age > fibSequence[i] * oneMillionBlocks) {
        skillPoints++;
      }
    }
    return skillPoints;
  };

  before(async function () {
    aavegotchiGameFacet = (await ethers.getContractAt(
      "AavegotchiGameFacet",
      diamondAddress
    )) as AavegotchiGameFacet;

    aavegotchiFacet = (await ethers.getContractAt(
      "contracts/Aavegotchi/facets/AavegotchiFacet.sol:AavegotchiFacet",
      diamondAddress
    )) as AavegotchiFacet;

    itemsFacet = (await ethers.getContractAt(
      "contracts/Aavegotchi/facets/ItemsFacet.sol:ItemsFacet",
      diamondAddress
    )) as ItemsFacet;

    for (let i = 0; i < gotchiIds.length; i++) {
      const skillPoints = await aavegotchiGameFacet.availableSkillPoints(
        gotchiIds[i]
      );
      availableSkillPointsBeforeUpgrade.push(Number(skillPoints.toString()));

      //todo: how can i get the AavegotchiInfo of an Aavegotchi from AavegotchiFacet? Typechain won't let me call getAavegotchi
      const aavegotchiInfo = await aavegotchiFacet.getAavegotchi(gotchiIds[i]);
      aavegotchis.push(aavegotchiInfo);
    }

    console.log("gotchis:", gotchiIds);
    console.log("aavegotchis:", aavegotchis);

    await upgrade();
  });

  // if they have available skill points, spend them and check the available skill points has decremented
  // use the respec potion and check the available skill points has incremented
  // check the decrement and increment amounts are correct
  // for this i need to access the spent vs the unspent points of an Aavegotchi
  it("Spend available then respec after upgrade", async function () {
    for (let i = 0; i < gotchiIds.length; i++) {
      console.log("gotchi:", gotchiIds[i]);
      
      const skillPoints1 = await aavegotchiGameFacet.availableSkillPoints(gotchiIds[i]);
      availableSkillPointsAfterUpgrade.push(Number(skillPoints1.toString()));

      if (availableSkillPointsAfterUpgrade[i] > 0) {
        // todo: how to unlock gotchi first?

        await aavegotchiGameFacet.spendSkillPoints(
          gotchiIds[i],
          [availableSkillPointsAfterUpgrade[i], 0, 0, 0]
        );

        const skillPoints2 = await aavegotchiGameFacet.availableSkillPoints(gotchiIds[i]);
        availableSkillPointsAfterSpend.push(Number(skillPoints2.toString()));

        expect(availableSkillPointsAfterUpgrade[i]).to.above(availableSkillPointsAfterSpend[i]);

        // todo: how to mint a respec potion for the testing account to use
        // todo: itemsFacet on Typechain won't let me call useConsumables (Typechain class for ItemFacet is not including useConsumables function)

        // await itemsFacet.useConsumables(gotchiIds[i], ['316'], ['1'])

        // const skillPoints3 = await aavegotchiGameFacet.availableSkillPoints(gotchiIds[i]);
        // availableSkillPointsAfterRespec.push(Number(skillPoints3.toString()));

        // expect(availableSkillPointsAfterSpend[i]).to.above(availableSkillPointsAfterUpgrade[i]);
      }
    }
  });

  /*
  it("Compare skill points before and after upgrade", async function () {
    for (let i = 0; i < gotchiIds.length; i++) {
      console.log("gotchi:", gotchiIds[i]);
      const skillPoint = await aavegotchiGameFacet.availableSkillPoints(
        gotchiIds[i]
      );
      skillPointsAfter.push(Number(skillPoint.toString()));
      const claimTime = (
        await aavegotchiFacet.aavegotchiClaimTime(gotchiIds[i])
      ).toString();
      const age = Math.floor(Date.now() / 1000) - Number(claimTime);
      console.log("age:", age, "claimTime:", claimTime);
      console.log("skillPointsBefore:", skillPointsBefore[i], "skillPointsAfter:", skillPointsAfter[i]);

      ages.push(age);
      // check only if gotchi is atleast 1M blocks old
      if (age > oneMillionBlocks) {
        expect(skillPointsAfter[i]).to.above(skillPointsBefore[i]);
      }

      console.log("skill points after:", skillPointsAfter);
    }
  });

  it("Check that skill points matches", async function () {
    for (let i = 0; i < gotchiIds.length; i++) {
      const agePts = calcSkillPoints(ages[i]);
      const totalPts = agePts + Number(skillPointsBefore[i]);
      const onchainPts = await aavegotchiGameFacet.availableSkillPoints(
        gotchiIds[i]
      );
      expect(totalPts).to.equal(Number(onchainPts));
    }
  });
  */
});
