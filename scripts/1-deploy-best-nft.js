  async function main() {
    const BestNFT = await ethers.getContractFactory("BestNFT");
    const bestNFT = await BestNFT.deploy("Best NFT", "BestNFT", "0x0613E0a9f9ab1035ae6C82A9f42b74Fd4f9c6504", 5);
    console.log("Contract deployed to address:", bestNFT.address);
 }
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });