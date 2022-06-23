//SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.6;

import "hardhat/console.sol";

//Uniswap interfaces and libraries
import "./libraries/Address.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract PancakeFlashSwap{
    using SafeERC20 for IERC20; //Swap approvals

    //Factory and Routing addresses
    address private constant PANCAKEFACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKEROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;   //Pancakeswap Router v2

    //Token Addresses
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;

    //Trade variables
    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    //Fund the Swap contract
    function fundFlashSwapContract(address _owner, address _token, uint256 _amount) public{
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    //Get this contract's balance
    function getBalanceOfToken(address _address) public view returns(uint256){
        return IERC20(_address).balanceOf(address(this));
    }

    //Place a trade
    function placeTrade(address _fromToken, address _toToken, uint256 _amountIn) private returns(uint256){
        address pair = IUniswapV2Factory(PANCAKEFACTORY).getPair(_fromToken, _toToken);
        require(pair != address(0));

        address [] memory path = new address [](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        //Get the amounts required for the swap to happen!
        uint256 amountRequired = IUniswapV2Router01(PANCAKEROUTER).getAmountsOut(_amountIn, path)[1];

        //Performs Arbitrage -Swap for another token
        uint256 amountReceived = IUniswapV2Router01(PANCAKEROUTER).swapExactTokensForTokens(_amountIn, 
                amountRequired, path, address(this), deadline)[1];

        require(amountReceived > 0, "Aborted transaction: Trade returned zero");
        return amountReceived;
    }

    function profitableTrade(uint256 _output, uint256 _input) internal returns(bool){
        return(_output > _input);
    }

    //Initiate Arbitrage
    //Begin receiving the loan to engage performing arbitrage trades
    function startArbitrage(address _tokenToBorrow, uint256 _amountToBorrow) external{
        IERC20(BUSD).safeApprove(address(PANCAKEROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKEROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKEROUTER), MAX_INT);

        //Get the factory address for the combined tokens. This is going to return the pair for _tokenToBorrow and
        //wBNB.
        address pair = IUniswapV2Factory(PANCAKEFACTORY).getPair(_tokenToBorrow, WBNB);

        //Return error if the pair doesn't exist
        require(pair != address(0), "Pool does not exist!");
        
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        //Find out which token has the amount and assign it. This will be _tokenToBorrow
        uint256 amount0Out = _tokenToBorrow == token0 ? _amountToBorrow : 0;
        uint256 amount1Out = _tokenToBorrow == token1 ? _amountToBorrow : 0;

        //Pass the data as bytes so that the swap function knows this is a flash swap (refer to documentation)
        bytes memory data = abi.encode(_tokenToBorrow, _amountToBorrow, msg.sender);

        //Execute the initial swap to get the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);  //This is going to call the upcoming pancakeCall function
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external{
        //Ensure this request came from the contract (from the swap call)
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(PANCAKEFACTORY).getPair(token0, token1);

        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "The sender should match this contract");

        //Decode the data for calculating the repayment
        (address tokenBorrow, uint256 amount, address myAddress) = abi.decode(_data, (address, uint256, address));

        //Calculate the amount to repay at the end
        uint256 fee = ((amount * 3) / 197) + 1;
        uint256 amountToPay = amount + fee;

        //DO ARBITRAGE!!!

        //AmountIn (BUSD) -> AmountOut (CROX), AmountIn(CROX) -> AmountOut(CAKE), AmountIn(CAKE) -> AmountOut(BUSD)
        //Pay BUSD back!
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;
        uint256 trade1ReceivedCoin = placeTrade(BUSD, CROX, loanAmount);
        uint256 trade2ReceivedCoin = placeTrade(CROX, CAKE, trade1ReceivedCoin);
        uint256 arbitrageResult = placeTrade(CAKE, BUSD, trade2ReceivedCoin);
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        //PAY YOURSELF FIRST!!!
        require(profitableTrade(arbitrageResult, amountToPay + tx.gasprice), "Trade was not profitable!");
        IERC20(tokenBorrow).transfer(myAddress, (arbitrageResult - (amountToPay + tx.gasprice)));

        //NOW PAY THE LOAN BACK!!!
        IERC20(tokenBorrow).transfer(pair, amountToPay);
    }
}
