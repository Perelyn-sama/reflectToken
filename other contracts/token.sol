
// SPDX-License-Identifier: Unlicensed
 
pragma solidity ^0.8.4;

import "./libraries.sol";
import "./imports.sol";
import "./interfaces.sol";
 
////////////////////////////////
/////////// Tokens /////////////
////////////////////////////////
 
contract GrandpaFloki is ERC20, Ownable {
    using SafeMath for uint256;
 
    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
 
    address public flokiDividendToken;
    address public flojrDividendToken;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
 
    bool private swapping;
    bool public marketingEnabled = true;
    bool public swapAndLiquifyEnabled = true;
    bool public flokiDividendEnabled = true;
    bool public flojrDividendEnabled = true;
    // this lets owner add LP while trading is stopped. One time function
    bool public lockTilStart = true;
    bool public lockUsed = false;
 
    FLOKIDividendTracker public flokiDividendTracker;
    FLOJRDividendTracker public flojrDividendTracker;
 
    address public marketingWallet;
    
    uint256 public maxWalletBalance = 2 * 10**9 * 10**18;
    uint256 public swapTokensAtAmount = 500 * 10**6 * 10**18;
 
    uint256 public liquidityFee = 2;
    uint256 public previousLiquidityFee;
    uint256 public flokiDividendRewardsFee = 5;
    uint256 public previousFlokiDividendRewardsFee;
    uint256 public flojrDividendRewardsFee = 5;
    uint256 public previousFlojrDividendRewardsFee;
    uint256 public marketingFee = 4;
    uint256 public previousMarketingFee;
    uint256 public totalFees = flokiDividendRewardsFee.add(marketingFee).add(flojrDividendRewardsFee).add(liquidityFee);
 
 
    uint256 public sellFeeIncreaseFactor = 150;
 
    uint256 public gasForProcessing = 50000;
 
    address public presaleAddress;
 
    mapping (address => bool) private isExcludedFromFees;
 
    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;
 
    event UpdateflokiDividendTracker(address indexed newAddress, address indexed oldAddress);
    event UpdateflojrDividendTracker(address indexed newAddress, address indexed oldAddress);
 
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
 
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MarketingEnabledUpdated(bool enabled);
    event FlokiDividendEnabledUpdated(bool enabled);
    event FlojrDividendEnabledUpdated(bool enabled);
    event LockTilStartUpdated(bool enabled);
 
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
 
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
 
    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
 
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
 
    event SendDividends(
    	uint256 amount
    );
 
    event ProcessedflokiDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
 
    event ProcessedflojrDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
 
    constructor() ERC20("GrandpaFloki", "GFLOKI") {
    	flokiDividendTracker = new FLOKIDividendTracker();
    	flojrDividendTracker = new FLOJRDividendTracker();
 
    	marketingWallet = 0x3497F3322aEA8FEaB5c8067efac73108F4cc8581;
    	flokiDividendToken = 0x2B3F34e9D4b127797CE6244Ea341a83733ddd6E4;
        flojrDividendToken = 0x338A09a17a7DA2E5c5a6B22344f3a49904224C79;
 
    	//0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 Testnet
    	//0x10ED43C718714eb63d5aA57B78B54704E256024E Mainet V2
    	
    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
 
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
 
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
 
        excludeFromDividend(address(flokiDividendTracker));
        excludeFromDividend(address(flojrDividendTracker));
        excludeFromDividend(address(this));
        excludeFromDividend(address(_uniswapV2Router));
        excludeFromDividend(deadAddress);
 
        // exclude from paying fees or having max transaction amount
        excludeFromFees(marketingWallet, true);
        excludeFromFees(address(this), true);
        excludeFromFees(deadAddress, true);
        excludeFromFees(owner(), true);
 
        setAuthOnDividends(owner());
 
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 100000000000 * (10**18));
    }
 
    receive() external payable {
 
  	}
 
  	function whitelistDxSale(address _presaleAddress, address _routerAddress) external onlyOwner {
  	    presaleAddress = _presaleAddress;
        flokiDividendTracker.excludeFromDividends(_presaleAddress);
        flojrDividendTracker.excludeFromDividends(_presaleAddress);
        excludeFromFees(_presaleAddress, true);
 
        flokiDividendTracker.excludeFromDividends(_routerAddress);
        flojrDividendTracker.excludeFromDividends(_routerAddress);
        excludeFromFees(_routerAddress, true);
  	}
 
  	function prepareForPartherOrExchangeListing(address _partnerOrExchangeAddress) external onlyOwner {
  	    flokiDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        flojrDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        excludeFromFees(_partnerOrExchangeAddress, true);
  	}
 
  	function setWalletBalance(uint256 _maxWalletBalance) external onlyOwner{
  	    maxWalletBalance = _maxWalletBalance;
  	}
 
  	function updateFlokiDividendToken(address _newContract) external onlyOwner {
  	    flokiDividendToken = _newContract;
  	    flokiDividendTracker.setDividendTokenAddress(_newContract);
  	}
 
  	function updateFlojrDividendToken(address _newContract) external onlyOwner {
  	    flojrDividendToken = _newContract;
  	    flojrDividendTracker.setDividendTokenAddress(_newContract);
  	}
 
  	function updateMarketingWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != marketingWallet, "GrandpaFloki: The marketing wallet is already this address");
        excludeFromFees(_newWallet, true);
        emit MarketingWalletUpdated(marketingWallet, _newWallet);
  	    marketingWallet = _newWallet;
  	}
 
  	function setSwapTokensAtAmount(uint256 _swapAmount) external onlyOwner {
  	    swapTokensAtAmount = _swapAmount * (10**18);
  	}
 
  	function setSellTransactionMultiplier(uint256 _multiplier) external onlyOwner {
  	    sellFeeIncreaseFactor = _multiplier;
  	}
 
 
    function setAuthOnDividends(address account) public onlyOwner{
        flojrDividendTracker.setAuth(account);
        flokiDividendTracker.setAuth(account);
    }
    
    function setLockTilStartEnabled(bool _enabled) external onlyOwner {
        if (lockUsed == false){
            lockTilStart = _enabled;
            lockUsed = true;
        }
        else{
            lockTilStart = false;
        }
        emit LockTilStartUpdated(lockTilStart);
    }
 
 
    function setFlokiDividendEnabled(bool _enabled) external onlyOwner {
        require(flokiDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousFlokiDividendRewardsFee = flokiDividendRewardsFee;
            flokiDividendRewardsFee = 0;
            flokiDividendEnabled = _enabled;
        } else {
            flokiDividendRewardsFee = previousFlokiDividendRewardsFee;
            totalFees = flokiDividendRewardsFee.add(marketingFee).add(flojrDividendRewardsFee).add(liquidityFee);
            flokiDividendEnabled = _enabled;
        }
 
        emit FlokiDividendEnabledUpdated(_enabled);
    }
 
    function setFlojrDividendEnabled(bool _enabled) external onlyOwner {
        require(flojrDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousFlojrDividendRewardsFee = flojrDividendRewardsFee;
            flojrDividendRewardsFee = 0;
            flojrDividendEnabled = _enabled;
        } else {
            flojrDividendRewardsFee = previousFlojrDividendRewardsFee;
            totalFees = flojrDividendRewardsFee.add(marketingFee).add(flokiDividendRewardsFee).add(liquidityFee);
            flojrDividendEnabled = _enabled;
        }
 
        emit FlojrDividendEnabledUpdated(_enabled);
    }
 
    function setMarketingEnabled(bool _enabled) external onlyOwner {
        require(marketingEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousMarketingFee = marketingFee;
            marketingFee = 0;
            marketingEnabled = _enabled;
        } else {
            marketingFee = previousMarketingFee;
            totalFees = marketingFee.add(flojrDividendRewardsFee).add(flokiDividendRewardsFee).add(liquidityFee);
            marketingEnabled = _enabled;
        }
 
        emit MarketingEnabledUpdated(_enabled);
    }
 
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        require(swapAndLiquifyEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousLiquidityFee = liquidityFee;
            liquidityFee = 0;
            swapAndLiquifyEnabled = _enabled;
        } else {
            liquidityFee = previousLiquidityFee;
            totalFees = flojrDividendRewardsFee.add(marketingFee).add(flokiDividendRewardsFee).add(liquidityFee);
            swapAndLiquifyEnabled = _enabled;
        }
 
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
 
 
    function updateflokiDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(flokiDividendTracker), "GrandpaFloki: The dividend tracker already has that address");
 
        FLOKIDividendTracker newflokiDividendTracker = FLOKIDividendTracker(payable(newAddress));
 
        require(newflokiDividendTracker.owner() == address(this), "GrandpaFloki: The new dividend tracker must be owned by the GrandpaFloki token contract");
 
        newflokiDividendTracker.excludeFromDividends(address(newflokiDividendTracker));
        newflokiDividendTracker.excludeFromDividends(address(this));
        newflokiDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newflokiDividendTracker.excludeFromDividends(address(deadAddress));
 
        emit UpdateflokiDividendTracker(newAddress, address(flokiDividendTracker));
 
        flokiDividendTracker = newflokiDividendTracker;
    }
 
    function updateflojrDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(flojrDividendTracker), "GrandpaFloki: The dividend tracker already has that address");
 
        FLOJRDividendTracker newflojrDividendTracker = FLOJRDividendTracker(payable(newAddress));
 
        require(newflojrDividendTracker.owner() == address(this), "GrandpaFloki: The new dividend tracker must be owned by the GrandpaFloki token contract");
 
        newflojrDividendTracker.excludeFromDividends(address(newflojrDividendTracker));
        newflojrDividendTracker.excludeFromDividends(address(this));
        newflojrDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newflojrDividendTracker.excludeFromDividends(address(deadAddress));
 
        emit UpdateflojrDividendTracker(newAddress, address(flojrDividendTracker));
 
        flojrDividendTracker = newflojrDividendTracker;
    }
 
    function updateFlokiDividendRewardFee(uint8 newFee) external onlyOwner {
        flokiDividendRewardsFee = newFee;
        totalFees = flokiDividendRewardsFee.add(marketingFee).add(flojrDividendRewardsFee).add(liquidityFee);
    }
 
    function updateFlojrDividendRewardFee(uint8 newFee) external onlyOwner {
        flojrDividendRewardsFee = newFee;
        totalFees = flojrDividendRewardsFee.add(flokiDividendRewardsFee).add(marketingFee).add(liquidityFee);
    }
 
    function updateMarketingFee(uint8 newFee) external onlyOwner {
        marketingFee = newFee;
        totalFees = marketingFee.add(flokiDividendRewardsFee).add(flojrDividendRewardsFee).add(liquidityFee);
    }
 
    function updateLiquidityFee(uint8 newFee) external onlyOwner {
        liquidityFee = newFee;
        totalFees = marketingFee.add(flokiDividendRewardsFee).add(flojrDividendRewardsFee).add(liquidityFee);
    }
 
    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "GrandpaFloki: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }
 
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "GrandpaFloki: Account is already exluded from fees");
        isExcludedFromFees[account] = excluded;
 
        emit ExcludeFromFees(account, excluded);
    }
 
    function excludeFromDividend(address account) public onlyOwner {
        flokiDividendTracker.excludeFromDividends(address(account));
        flojrDividendTracker.excludeFromDividends(address(account));
    }
 
    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }
 
        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }
 
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "GrandpaFloki: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
 
        _setAutomatedMarketMakerPair(pair, value);
    }
 
    function _setAutomatedMarketMakerPair(address pair, bool value) private onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "GrandpaFloki: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;
 
        if(value) {
            flokiDividendTracker.excludeFromDividends(pair);
            flojrDividendTracker.excludeFromDividends(pair);
        }
 
        emit SetAutomatedMarketMakerPair(pair, value);
    }
 
    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue != gasForProcessing, "GrandpaFloki: Cannot update gasForProcessing to same value");
        gasForProcessing = newValue;
        emit GasForProcessingUpdated(newValue, gasForProcessing);
    }
 
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external onlyOwner {
        flokiDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
        flojrDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
    }
 
    function updateClaimWait(uint256 claimWait) external onlyOwner {
        flokiDividendTracker.updateClaimWait(claimWait);
        flojrDividendTracker.updateClaimWait(claimWait);
    }
 
    function getFlokiClaimWait() external view returns(uint256) {
        return flokiDividendTracker.claimWait();
    }
 
    function getFlojrClaimWait() external view returns(uint256) {
        return flojrDividendTracker.claimWait();
    }
 
    function getTotalFlokiDividendsDistributed() external view returns (uint256) {
        return flokiDividendTracker.totalDividendsDistributed();
    }
 
    function getTotalFlojrDividendsDistributed() external view returns (uint256) {
        return flojrDividendTracker.totalDividendsDistributed();
    }
 
    function getIsExcludedFromFees(address account) public view returns(bool) {
        return isExcludedFromFees[account];
    }
 
    function withdrawableFlokiDividendOf(address account) external view returns(uint256) {
    	return flokiDividendTracker.withdrawableDividendOf(account);
  	}
 
  	function withdrawableFlojrDividendOf(address account) external view returns(uint256) {
    	return flojrDividendTracker.withdrawableDividendOf(account);
  	}
 
	function flokiDividendTokenBalanceOf(address account) external view returns (uint256) {
		return flokiDividendTracker.balanceOf(account);
	}
 
	function flojrDividendTokenBalanceOf(address account) external view returns (uint256) {
		return flojrDividendTracker.balanceOf(account);
	}
 
    function getAccountFlokiDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return flokiDividendTracker.getAccount(account);
    }
 
    function getAccountFlojrDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return flojrDividendTracker.getAccount(account);
    }
 
	function getAccountFlokiDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return flokiDividendTracker.getAccountAtIndex(index);
    }
 
    function getAccountFlojrDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return flojrDividendTracker.getAccountAtIndex(index);
    }
 
	function processDividendTracker(uint256 gas) external onlyOwner {
		(uint256 FlokiIterations, uint256 FlokiClaims, uint256 FlokiLastProcessedIndex) = flokiDividendTracker.process(gas);
		emit ProcessedflokiDividendTracker(FlokiIterations, FlokiClaims, FlokiLastProcessedIndex, false, gas, tx.origin);
 
		(uint256 flojrIterations, uint256 flojrClaims, uint256 flojrLastProcessedIndex) = flojrDividendTracker.process(gas);
		emit ProcessedflojrDividendTracker(flojrIterations, flojrClaims, flojrLastProcessedIndex, false, gas, tx.origin);
    }
 
    function claim() external {
		flokiDividendTracker.processAccount(payable(msg.sender), false);
		flojrDividendTracker.processAccount(payable(msg.sender), false);
    }
    function getLastFlokiDividendProcessedIndex() external view returns(uint256) {
    	return flokiDividendTracker.getLastProcessedIndex();
    }
 
    function getLastFlojrDividendProcessedIndex() external view returns(uint256) {
    	return flojrDividendTracker.getLastProcessedIndex();
    }
 
    function getNumberOfFlokiDividendTokenHolders() external view returns(uint256) {
        return flokiDividendTracker.getNumberOfTokenHolders();
    }
 
    function getNumberOfFlojrDividendTokenHolders() external view returns(uint256) {
        return flojrDividendTracker.getNumberOfTokenHolders();
    }
 
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(lockTilStart != true || from == owner());
 
        bool excludedAccount = isExcludedFromFees[from] || isExcludedFromFees[to];
        
        if (to != address(0) && to != address(0xdead) && from != address(this) && to != address(this)) {
            if (from == uniswapV2Pair) {
                require(balanceOf(to).add(amount) <= maxWalletBalance, "Exceeds maximum wallet token amount.");
            }
        }
 
 
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
 
        if (!swapping && canSwap && from != uniswapV2Pair) {
            swapping = true;
 
            if (marketingEnabled) {
                uint256 initialBalance = address(this).balance;
                uint256 swapTokens = contractTokenBalance.div(totalFees).mul(marketingFee);
                swapTokensForBNB(swapTokens);
                uint256 marketingPortion = address(this).balance.sub(initialBalance);
                transferToWallet(payable(marketingWallet), marketingPortion);
                
            }
 
            if(swapAndLiquifyEnabled) {
                uint256 liqTokens = contractTokenBalance.div(totalFees).mul(liquidityFee);
                swapAndLiquify(liqTokens);
            }
 
            if (flokiDividendEnabled) {
                uint256 FlokiTokens = contractTokenBalance.div(totalFees).mul(flokiDividendRewardsFee);
                swapAndSendFlokiDividends(FlokiTokens);
            }
 
            if (flojrDividendEnabled) {
                uint256 flojrTokens = contractTokenBalance.div(totalFees).mul(flojrDividendRewardsFee);
                swapAndSendFlojrDividends(flojrTokens);
            }
 
                swapping = false;
        }
 
        bool takeFee =  !swapping && !excludedAccount;
 
        if(takeFee) {
        	uint256 fees = amount.div(100).mul(totalFees);
 
            // if sell, multiply by 1.2
            if(automatedMarketMakerPairs[to]) {
                fees = fees.div(100).mul(sellFeeIncreaseFactor);
            }
 
        	amount = amount.sub(fees);
 
            super._transfer(from, address(this), fees);
        }
 
        super._transfer(from, to, amount);
 
        try flokiDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try flojrDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try flokiDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
        try flojrDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
 
        if(!swapping) {
	    	uint256 gas = gasForProcessing;
 
	    	try flokiDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedflokiDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {
 
	    	}
 
	    	try flojrDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedflojrDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {
 
	    	}
        }
    }
 
 
    function swapAndLiquify(uint256 contractTokenBalance) private {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
 
        uint256 initialBalance = address(this).balance;
 
        swapTokensForBNB(half);
 
        uint256 newBalance = address(this).balance.sub(initialBalance);
 
        addLiquidity(otherHalf, newBalance);
 
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
 
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
 
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
 
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            marketingWallet,
            block.timestamp
        );
    }
 
 
    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
 
        _approve(address(this), address(uniswapV2Router), tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
 
    }
 
    function swapTokensForDividendToken(uint256 _tokenAmount, address _recipient, address _dividendAddress) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = _dividendAddress;
 
        _approve(address(this), address(uniswapV2Router), _tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount of dividend token
            path,
            _recipient,
            block.timestamp
        );
    }
 
    function swapAndSendFlokiDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), flokiDividendToken);
        uint256 flokiDividends = IERC20(flokiDividendToken).balanceOf(address(this));
        transferDividends(flokiDividendToken, address(flokiDividendTracker), flokiDividendTracker, flokiDividends);
    }
 
    function swapAndSendFlojrDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), flojrDividendToken);
        uint256 flojrDividends = IERC20(flojrDividendToken).balanceOf(address(this));
        transferDividends(flojrDividendToken, address(flojrDividendTracker), flojrDividendTracker, flojrDividends);
    }
 
    function transferToWallet(address payable recipient, uint256 amount) private {
        uint256 mktng = amount;
        recipient.transfer(mktng);
    }
 
    function transferDividends(address dividendToken, address dividendTracker, DividendPayingToken dividendPayingTracker, uint256 amount) private {
        bool success = IERC20(dividendToken).transfer(dividendTracker, amount);
 
        if (success) {
            dividendPayingTracker.distributeDividends(amount);
            emit SendDividends(amount);
        }
    }
}
 
contract FLOKIDividendTracker is DividendPayingToken, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;
 
    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
 
    mapping (address => bool) public excludedFromDividends;
 
    mapping (address => uint256) public lastClaimTimes;
 
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;
 
    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event Claim(address indexed account, uint256 amount, bool indexed automatic);
 
    constructor() DividendPayingToken("GrandpaFloki_Floki_Dividend_Tracker", "GrandpaFloki_Floki_Dividend_Tracker", 0x2B3F34e9D4b127797CE6244Ea341a83733ddd6E4) {
    	claimWait = 1800;
        minimumTokenBalanceForDividends = 2000000 * (10**18); //must hold 2000000+ tokens
    }
 
    function _transfer(address, address, uint256) pure internal override {
        require(false, "GrandpaFloki_Floki_Dividend_Tracker: No transfers allowed");
    }
 
    function withdrawDividend() pure public override {
        require(false, "GrandpaFloki_Floki_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main GrandpaFloki contract.");
    }
 
    function setDividendTokenAddress(address newToken) external override onlyOwner {
      dividendToken = newToken;
    }
 
    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance != minimumTokenBalanceForDividends, "New mimimum balance for dividend cannot be same as current minimum balance");
        minimumTokenBalanceForDividends = _newMinimumBalance * (10**18);
    }
 
    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
    	excludedFromDividends[account] = true;
 
    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);
 
    	emit ExcludeFromDividends(account);
    }
 
    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 1800 && newClaimWait <= 86400, "GrandpaFloki_Floki_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "GrandpaFloki_Floki_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }
 
    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }
 
    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }
 
 
    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;
 
        index = tokenHoldersMap.getIndexOfKey(account);
 
        iterationsUntilProcessed = -1;
 
        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;
 
 
                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }
 
 
        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);
 
        lastClaimTime = lastClaimTimes[account];
 
        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;
 
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }
 
    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }
 
        address account = tokenHoldersMap.getKeyAtIndex(index);
 
        return getAccount(account);
    }
 
    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}
 
    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }
 
    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}
 
    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}
 
    	processAccount(account, true);
    }
 
    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
 
    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}
 
    	uint256 _lastProcessedIndex = lastProcessedIndex;
 
    	uint256 gasUsed = 0;
 
    	uint256 gasLeft = gasleft();
 
    	uint256 iterations = 0;
    	uint256 claims = 0;
 
    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;
 
    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}
 
    		address account = tokenHoldersMap.keys[_lastProcessedIndex];
 
    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}
 
    		iterations++;
 
    		uint256 newGasLeft = gasleft();
 
    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}
 
    		gasLeft = newGasLeft;
    	}
 
    	lastProcessedIndex = _lastProcessedIndex;
 
    	return (iterations, claims, lastProcessedIndex);
    }
 
    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);
 
    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}
 
    	return false;
    }
}
 
contract FLOJRDividendTracker is DividendPayingToken, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;
 
    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
 
    mapping (address => bool) public excludedFromDividends;
 
    mapping (address => uint256) public lastClaimTimes;
 
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;
 
    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event Claim(address indexed account, uint256 amount, bool indexed automatic);
 
    constructor() DividendPayingToken("GrandpaFloki_Flojr_Dividend_Tracker", "GrandpaFloki_Flojr_Dividend_Tracker", 0x338A09a17a7DA2E5c5a6B22344f3a49904224C79) {
    	claimWait = 1800;
        minimumTokenBalanceForDividends = 2000000 * (10**18); //must hold 2000000+ tokens
    }
 
    function _transfer(address, address, uint256) pure internal override {
        require(false, "GrandpaFloki_Flojr_Dividend_Tracker: No transfers allowed");
    }
 
    function withdrawDividend() pure public override {
        require(false, "GrandpaFloki_Flojr_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main GrandpaFloki contract.");
    }
 
    function setDividendTokenAddress(address newToken) external override onlyOwner {
      dividendToken = newToken;
    }
 
    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance != minimumTokenBalanceForDividends, "New mimimum balance for dividend cannot be same as current minimum balance");
        minimumTokenBalanceForDividends = _newMinimumBalance * (10**18);
    }
 
    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
    	excludedFromDividends[account] = true;
 
    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);
 
    	emit ExcludeFromDividends(account);
    }
 
    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 1800 && newClaimWait <= 86400, "GrandpaFloki_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "GrandpaFloki_Flojr_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }
 
    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }
 
    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }
 
 
    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;
 
        index = tokenHoldersMap.getIndexOfKey(account);
 
        iterationsUntilProcessed = -1;
 
        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;
 
 
                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }
 
 
        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);
 
        lastClaimTime = lastClaimTimes[account];
 
        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;
 
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }
 
    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }
 
        address account = tokenHoldersMap.getKeyAtIndex(index);
 
        return getAccount(account);
    }
 
    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}
 
    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }
 
    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}
 
    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}
 
    	processAccount(account, true);
    }
 
    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
 
    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}
 
    	uint256 _lastProcessedIndex = lastProcessedIndex;
 
    	uint256 gasUsed = 0;
 
    	uint256 gasLeft = gasleft();
 
    	uint256 iterations = 0;
    	uint256 claims = 0;
 
    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;
 
    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}
 
    		address account = tokenHoldersMap.keys[_lastProcessedIndex];
 
    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}
 
    		iterations++;
 
    		uint256 newGasLeft = gasleft();
 
    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}
 
    		gasLeft = newGasLeft;
    	}
 
    	lastProcessedIndex = _lastProcessedIndex;
 
    	return (iterations, claims, lastProcessedIndex);
    }
 
    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);
 
    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}
 
    	return false;
    }
}