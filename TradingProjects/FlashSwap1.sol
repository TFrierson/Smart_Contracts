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
    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
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

    //Initiate Arbitrage
    //Begin receiving the loan to engage performing arbitrage trades
    function startArbitrage(address _tokenToBorrow, uint256 _amountToBorrow) external{
        IERC20(BUSD).safeApprove(address(PANCAKEROUTER), MAX_INT);
        IERC20(USDT).safeApprove(address(PANCAKEROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKEROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKEROUTER), MAX_INT);

        //Get the factory address for the combined tokens
        address pair = IUniswapV2Factory(PANCAKEFACTORY).getPair(_tokenToBorrow, WBNB);

        //Return error if the pair doesn't exist
        require(pair != address(0), "Pool does not exist!");

        //Find out which token has the amount and assign it
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        uint256 amount0Out = _tokenToBorrow == token0 ? _amountToBorrow : 0;
        uint256 amount1Out = _tokenToBorrow == token1 ? _amountToBorrow : 0;

        //Pass the data as bytes so that the swap function knows this is a flash swap (refer to documentation)
        bytes memory data = abi.encode(_tokenToBorrow, _amountToBorrow);

        //Execute the initial swap to get the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);  //This is going to call the upcoming pancakeCall function
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external{
        //Ensure this request came from the contract
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(PANCAKEFACTORY).getPair(token0, token1);

        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "The sender should match this contract");

        //Decode the data for calculating the repayment
        (address tokenBorrow, uint256 amount) = abi.decode(_data, (address, uint256));

        //Calculate the amount to repay at the end
        uint256 fee = ((amount * 3) / 197) + 1;
        uint256 amountToPay = amount + fee;

        //DO ARBITRAGE!!!
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        //PAY YOURSELF FIRST!!!

        //NOW PAY THE LOAN BACK!!!
        IERC20(tokenBorrow).transfer(pair, amountToPay);
    }
}
