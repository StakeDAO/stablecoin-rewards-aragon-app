# Stablecoin Rewards Distribution Aragon App

The rewards distribution app is used to distribute rewards earned at the end of each StakeDAO cycle. It will distribute
rewards earned during the previous cycle relative to the time an individual stakes tokens in the current cycle. Eg
someone who stakes half way through cycle 2, will receive half of cycle 1's distribution. In the future we hope to 
correct this disparity and update the contract to distribute the most current cycles earnings as opposed to the 
previous one's earnings.

The contract is originally based on this Synthetix Unipool implementation: 
https://github.com/Synthetixio/Unipool/blob/master/contracts/Unipool.sol

## Local Deployment

Install dependencies:
```
$ npm install
```
May require `npm install node-gyp` first

### Test
```
$ npm run test
```

### App Deployment
In a separate terminal start the devchain:
```
$ npx aragon devchain
```
In a separate terminal start the client (the web portion of the app):
```
$ npm run start:app
```
In a separate terminal deploy the DAO with:
```
$ npm run start:http:template
```