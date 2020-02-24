# Stablecoin Rewards Distribution Aragon App

The rewards distribution app is used to distribute rewards earned at the end of each StakeDAO cycle. It will distribute
rewards earned during the previous cycle relative to the time an individual stakes tokens in the current cycle. Eg
someone who stakes half way through cycle 2, will receive half of cycle 1's distribution. In the future we hope to 
correct this disparity and update the contract to distribute the most current cycles earnings as opposed to the 
previous one's earnings.

The contract is originally based on this Synthetix Unipool implementation: 
https://github.com/Synthetixio/Unipool/blob/master/contracts/Unipool.sol

This app also uses a forked version of the Aragon Token Wrapper found here: 
https://github.com/aragonone/voting-connectors

## Local Deployment

1) Install dependencies:
```
$ npm install
```
May require `npm install node-gyp` first

2) In a separate terminal start the devchain:
```
$ npx aragon devchain
```

3) Deploy the Token-Wrapper to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/StakeDAO/voting-connectors
- Run `npm install` in the `apps/token-wrapper` folder
- Execute `npm run apm:publish major`

4) Deploy the CycleManager app to the devchain as it's not installed by default like the other main apps (Voting, Token Manager, Agent etc):
- Download https://github.com/StakeDAO/cycle-manager-aragon-app
- Run `npm install` in the root folder
- Execute `npm run build` in the root folder
- Execute `npm run publish:major` in the root folder

5) Deploy mock SCT and DAI and tokens:
```
$ truffle exec scripts/deployTokens.js --network rpc
```
Copy the SCT and DAI token addresses output to the `package.json` script `start:http:template` directly after the `--template-args` arg
replacing the 2 addresses that are there already.

6) In a separate terminal start the client (the web portion of the app):
```
$ npm run start:app
```
7) In a separate terminal deploy a DAO including the app with:
```
$ npm run start:http:template
```