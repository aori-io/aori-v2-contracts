tests:
	forge test --fork-url https://rpc.ankr.com/eth_sepolia --via-ir -vvv
gas-report:
	forge test --fork-url https://rpc.ankr.com/eth_sepolia --via-ir --gas-report
deploy:
	forge script script/Deploy.s.sol:DeployScript --legacy --broadcast
test-deploy:
	forge script script/Deploy.s.sol:DeployScript --legacy
generate-etherscan:
	forge verify-contract 0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5 src/AoriV2.sol:AoriV2 --optimizer-runs 1000000 --show-standard-json-input > etherscan/aori-v2-etherscan.json
	forge verify-contract 0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5 src/AoriV2Blast.sol:AoriV2Blast --optimizer-runs 1000000 --show-standard-json-input > etherscan/aori-v2-blast-etherscan.json