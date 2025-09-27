const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 Starting Ultrana DEX Smart Contract Deployment...");
    
    // Get the deployer account
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    
    // Deployment configuration
    const deploymentConfig = {
        // Token configuration
        tokenName: "Ultrana DEX Token",
        tokenSymbol: "ULTRA",
        tokenSupply: ethers.utils.parseEther("1000000000"), // 1B tokens
        
        // Governance configuration
        votingPeriod: 7 * 24 * 60 * 60, // 7 days
        executionDelay: 2 * 24 * 60 * 60, // 2 days
        proposalThreshold: ethers.utils.parseEther("1000000"), // 1M tokens
        quorumThreshold: 10, // 10%
        supermajorityThreshold: 66, // 66%
        
        // Staking configuration
        rewardRate: ethers.utils.parseEther("1000"), // 1000 tokens per second
        stakingDuration: 365 * 24 * 60 * 60, // 1 year
        
        // Security configuration
        maxSlippage: 500, // 5%
        maxPriceImpact: 1000, // 10%
        minLiquidity: ethers.utils.parseEther("10000"), // 10K tokens
        maxGasPrice: ethers.utils.parseUnits("100", "gwei"), // 100 gwei
        
        // Fee configuration
        defaultFeeTier: 3000, // 0.3%
        feeToSetter: deployer.address,
        
        // WETH address (mainnet)
        WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    };
    
    const deployedContracts = {};
    
    try {
        // 1. Deploy Ultrana DEX Token
        console.log("\n📝 Deploying Ultrana DEX Token...");
        const UltranaDEXToken = await ethers.getContractFactory("UltranaDEXToken");
        const token = await UltranaDEXToken.deploy(
            deploymentConfig.tokenName,
            deploymentConfig.tokenSymbol,
            deploymentConfig.tokenSupply
        );
        await token.deployed();
        deployedContracts.UltranaDEXToken = token.address;
        console.log("✅ UltranaDEXToken deployed to:", token.address);
        
        // 2. Deploy MEV Protection
        console.log("\n🛡️ Deploying MEV Protection...");
        const MEVProtection = await ethers.getContractFactory("MEVProtection");
        const mevProtection = await MEVProtection.deploy(
            deployer.address, // securityManager
            deployer.address, // oracle (placeholder)
            deploymentConfig.maxSlippage,
            deploymentConfig.maxPriceImpact,
            deploymentConfig.minLiquidity,
            deploymentConfig.maxGasPrice
        );
        await mevProtection.deployed();
        deployedContracts.MEVProtection = mevProtection.address;
        console.log("✅ MEVProtection deployed to:", mevProtection.address);
        
        // 3. Deploy Slippage Protection
        console.log("\n📊 Deploying Slippage Protection...");
        const SlippageProtection = await ethers.getContractFactory("SlippageProtection");
        const slippageProtection = await SlippageProtection.deploy(
            deployer.address, // securityManager
            deploymentConfig.maxSlippage
        );
        await slippageProtection.deployed();
        deployedContracts.SlippageProtection = slippageProtection.address;
        console.log("✅ SlippageProtection deployed to:", slippageProtection.address);
        
        // 4. Deploy Factory
        console.log("\n🏭 Deploying UltranaDEXFactory...");
        const UltranaDEXFactory = await ethers.getContractFactory("UltranaDEXFactory");
        const factory = await UltranaDEXFactory.deploy(deploymentConfig.feeToSetter);
        await factory.deployed();
        deployedContracts.UltranaDEXFactory = factory.address;
        console.log("✅ UltranaDEXFactory deployed to:", factory.address);
        
        // 5. Deploy Router
        console.log("\n🛣️ Deploying UltranaDEXRouter...");
        const UltranaDEXRouter = await ethers.getContractFactory("UltranaDEXRouter");
        const router = await UltranaDEXRouter.deploy(
            factory.address,
            deploymentConfig.WETH
        );
        await router.deployed();
        deployedContracts.UltranaDEXRouter = router.address;
        console.log("✅ UltranaDEXRouter deployed to:", router.address);
        
        // 6. Deploy Governance
        console.log("\n🗳️ Deploying UltranaDEXGovernance...");
        const UltranaDEXGovernance = await ethers.getContractFactory("UltranaDEXGovernance");
        const governance = await UltranaDEXGovernance.deploy(
            token.address,
            deploymentConfig.votingPeriod,
            deploymentConfig.executionDelay,
            deploymentConfig.proposalThreshold,
            deploymentConfig.quorumThreshold,
            deploymentConfig.supermajorityThreshold
        );
        await governance.deployed();
        deployedContracts.UltranaDEXGovernance = governance.address;
        console.log("✅ UltranaDEXGovernance deployed to:", governance.address);
        
        // 7. Deploy Staking
        console.log("\n💰 Deploying UltranaDEXStaking...");
        const UltranaDEXStaking = await ethers.getContractFactory("UltranaDEXStaking");
        const staking = await UltranaDEXStaking.deploy(
            token.address, // stakingToken
            token.address, // rewardToken
            deploymentConfig.rewardRate
        );
        await staking.deployed();
        deployedContracts.UltranaDEXStaking = staking.address;
        console.log("✅ UltranaDEXStaking deployed to:", staking.address);
        
        // 8. Configure contracts
        console.log("\n⚙️ Configuring contracts...");
        
        // Set router in factory
        await factory.setRouter(router.address);
        console.log("✅ Router set in factory");
        
        // Set security manager in factory
        await factory.setSecurityManager(deployer.address);
        console.log("✅ Security manager set in factory");
        
        // Set MEV protection in router
        await router.setMEVProtection(mevProtection.address);
        console.log("✅ MEV protection set in router");
        
        // Set slippage protection in router
        await router.setSlippageProtection(slippageProtection.address);
        console.log("✅ Slippage protection set in router");
        
        // Set security manager in governance
        await governance.setSecurityManager(deployer.address);
        console.log("✅ Security manager set in governance");
        
        // Set MEV protection in governance
        await governance.setMEVProtection(mevProtection.address);
        console.log("✅ MEV protection set in governance");
        
        // Set security manager in staking
        await staking.setSecurityManager(deployer.address);
        console.log("✅ Security manager set in staking");
        
        // Set MEV protection in staking
        await staking.setMEVProtection(mevProtection.address);
        console.log("✅ MEV protection set in staking");
        
        // 9. Create initial staking pools
        console.log("\n🏊 Creating initial staking pools...");
        
        // 30-day pool
        await staking.createPool(
            30 * 24 * 60 * 60, // 30 days
            500, // 5% APY
            ethers.utils.parseEther("1000000") // 1M max stake
        );
        console.log("✅ 30-day staking pool created");
        
        // 90-day pool
        await staking.createPool(
            90 * 24 * 60 * 60, // 90 days
            1000, // 10% APY
            ethers.utils.parseEther("5000000") // 5M max stake
        );
        console.log("✅ 90-day staking pool created");
        
        // 365-day pool
        await staking.createPool(
            365 * 24 * 60 * 60, // 365 days
            2000, // 20% APY
            ethers.utils.parseEther("10000000") // 10M max stake
        );
        console.log("✅ 365-day staking pool created");
        
        // 10. Save deployment information
        const deploymentInfo = {
            network: await ethers.provider.getNetwork(),
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: deployedContracts,
            configuration: deploymentConfig
        };
        
        // Save to file
        const deploymentPath = path.join(__dirname, "..", "deployments", `${await ethers.provider.getNetwork().then(n => n.name)}.json`);
        fs.mkdirSync(path.dirname(deploymentPath), { recursive: true });
        fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
        
        console.log("\n🎉 Deployment completed successfully!");
        console.log("📄 Deployment info saved to:", deploymentPath);
        
        // 11. Verify contracts (if on mainnet/testnet)
        if (process.env.VERIFY_CONTRACTS === "true") {
            console.log("\n🔍 Verifying contracts on Etherscan...");
            try {
                await hre.run("verify:verify", {
                    address: token.address,
                    constructorArguments: [
                        deploymentConfig.tokenName,
                        deploymentConfig.tokenSymbol,
                        deploymentConfig.tokenSupply
                    ]
                });
                console.log("✅ Token verified");
            } catch (error) {
                console.log("❌ Token verification failed:", error.message);
            }
        }
        
        // 12. Display summary
        console.log("\n📋 Deployment Summary:");
        console.log("====================");
        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`${name}: ${address}`);
        });
        
        console.log("\n🔗 Next Steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Set up monitoring and alerts");
        console.log("3. Configure frontend integration");
        console.log("4. Conduct security audit");
        console.log("5. Launch with limited liquidity");
        
    } catch (error) {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
