/* global artifacts */
var CounterApp = artifacts.require('StablecoinRewards.sol')

module.exports = function(deployer) {
  deployer.deploy(CounterApp)
}
