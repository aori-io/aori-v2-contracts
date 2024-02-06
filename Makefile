tests:
	forge test --fork-url https://rpc.ankr.com/eth_goerli --via-ir -vvv
gas-report:
	forge test --fork-url https://rpc.ankr.com/eth_goerli --via-ir --gas-report

test-deploy-goerli:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_goerli --via-ir --broadcast
test-deploy-sepolia:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_sepolia --via-ir --broadcast
test-deploy-arbitrum-sepolia:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://sepolia-rollup.arbitrum.io/rpc --via-ir --broadcast
test-deploy-arbitrum:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://arb1.arbitrum.io/rpc --via-ir --broadcast --legacy
test-deploy-mevm-m1:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://mevm.devnet.m1.movementlabs.xyz/v1 --via-ir --broadcast