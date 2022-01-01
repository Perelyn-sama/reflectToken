const ReflectToken = artifacts.require("ReflectToken");

module.exports = function (deployer) {
  deployer.deploy(ReflectToken);
};
