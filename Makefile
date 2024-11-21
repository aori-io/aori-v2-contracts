build:
	forge build
tests:
	forge test --fork-url https://rpc.ankr.com/eth_sepolia --via-ir -vvv
gas-report:
	forge test --fork-url https://rpc.ankr.com/eth_sepolia --via-ir --gas-report
deploy:
	forge script script/Deploy.s.sol:DeployScript --legacy --broadcast
test-deploy:
	forge script script/Deploy.s.sol:DeployScript --legacy
generate-etherscan:
	forge verify-contract 0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506 src/AoriV2.sol:AoriV2 --optimizer-runs 1000000 --show-standard-json-input > etherscan/aori-v2-3-etherscan.json
	forge verify-contract 0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506 src/AoriV2Blast.sol:AoriV2Blast --optimizer-runs 1000000 --show-standard-json-input > etherscan/aori-v2-3-blast-etherscan.json