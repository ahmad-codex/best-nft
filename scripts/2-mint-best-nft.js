// Get Alchemy API Key
const API_KEY = process.env.API_KEY;

// Define an Alchemy Provider
const provider = new ethers.providers.AlchemyProvider('goerli', API_KEY);
const contract = require("../artifacts/contracts/BestNFT.sol/BestNFT.json");

// Create a signer
const privateKey = process.env.PRIVATE_KEY
const signer = new ethers.Wallet(privateKey, provider)

// Get contract ABI and address
const abi = contract.abi
const contractAddress = process.env.NFT_Contract_ADDRESS;

// Create a contract instance
const nftContract = new ethers.Contract(contractAddress, abi, signer)

const mintNFT = async () => {
    let nftTxn = await nftContract.mintTo("0xB92D1720eAF9CAc95C004A4251B1542774D45235", 5);
    await nftTxn.wait()
    console.log(`NFT Minted! Check it out at: https://goerli.etherscan.io/tx/${nftTxn.hash}`)
}

mintNFT()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });