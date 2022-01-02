// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ReflectToken is ERC20 {

    mapping(address => bool) private _isExcluded;

    uint256 private constant pointMultiplier = 10 ** 18;

    struct Account {
        uint balance;
        uint lastDividendPoints;
    }

    mapping(address => Account) public accounts;

    uint private totalDividendPoints;

    uint private unclaimedDividends;

    uint private reflectionFee;

    uint private blackListAmount;

    mapping(address => bool) private isBlackListed;

    constructor() ERC20("ReflectToken", "RFT") {
        _isExcluded[msg.sender] = true;
        _mint(msg.sender, 1000000000000);
    }
}

