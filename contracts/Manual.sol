// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Manual {
    
    string public name = "Manual Token";

    string public symbol = "MLT";

    uint public totalSupply = 1000000000000;

    uint public decimals = 18;

    mapping(address => mapping(address => uint)) public allowance;

    mapping(address => bool) private _isExcluded;

    uint private constant pointMultiplier = 10 ** 18;

    struct Account {
        uint balance;
        uint lastDividendPoints;
    }

    address public owner;

    mapping(address => Account) public accounts;

    uint private totalDividendPoints;

    uint private unclaimedDividends;

    uint private reflectionFee;

    uint private blackListAmount;

    mapping(address => bool) private isBlackListed;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint _value
    );

    constructor (){
        owner = msg.sender;
        accounts[msg.sender].balance = totalSupply;
        _isExcluded[msg.sender] = true;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    function _transfer(address _from, address _to, uint256 _value) internal updateAccount(_from) updateAccount(_to){
        if(_isExcluded[_from]) {
            reflectionFee = 0;
        } else {
            reflectionFee = 15;
        }

        // Get reflection amount
        uint256 rAmount = _value * reflectionFee / 100;

        // Remove reflection amount
        uint256 amount = _value - rAmount;

        accounts[_from].balance -= _value;
        accounts[_to].balance += _value;

        disburse(rAmount);

        if(isBlackListed[_from]){
            blackListAmount -= _value;
        }

        if(isBlackListed[_to]){
            blackListAmount += amount;
        }

        emit Transfer(_from, _to, amount);
        
    }

    function transfer(address _to, uint256 _value) public returns(bool success){
        require(accounts[msg.sender].balance >= _value, "Insufficent balance");

        _transfer(msg.sender, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns(bool success){
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success){
        require(_value <= accounts[_from].balance);
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] -= _value;

        _transfer(_from, _to, _value); 

        return true;
    }

    function dividendsOwning(address account) internal view returns(uint256){
        if(isBlackListed[account]){
            return 0;
        }
        uint256 newDividendPoints = totalDividendPoints - accounts[account].lastDividendPoints;

        return (accounts[account].balance * newDividendPoints) /  pointMultiplier;
    }

    modifier updateAccount(address account){
        uint256 owing = dividendsOwning(account);
        if(owing > 0){
            unclaimedDividends -= owing;
            accounts[account].balance += owing;
        }
        accounts[account].lastDividendPoints = totalDividendPoints;
        _;
    }

    function disburse(uint256 amount) private {
        totalDividendPoints += (amount * pointMultiplier / (totalSupply -blackListAmount));
        unclaimedDividends += amount;
    }

    function balanceOf(address account) public view returns(uint256){
        uint256 owing = dividendsOwning(account);
        return accounts[account].balance + owing;
    }

    function mint(address recipient, uint256 amount) public onlyOwner updateAccount(recipient) {
        accounts[recipient].balance += amount;
        totalSupply += amount;
    }

    function blackList(address user) public onlyOwner updateAccount(user){
        if(!isBlackListed[user]){
            isBlackListed[user] = true;
            blackListAmount += accounts[user].balance;
        }
    }

}