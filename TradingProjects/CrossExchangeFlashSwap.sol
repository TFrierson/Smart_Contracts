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

contract UniswapCrossFlash{
    using SafeERC20 for IERC20; //Swap approvals

    //Factory and Routing addresses
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;  //Uniswap Router02
    address private constant SUSHISWAP_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private constant SUSHISWAP_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    //Token Addresses
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

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
    function placeTrade(address _fromToken, address _toToken, 
            uint256 _amountIn, address _factory, address _router) private returns(uint256){
        address pair = IUniswapV2Factory(_factory).getPair(_fromToken, _toToken);
        require(pair != address(0));

        address [] memory path = new address [](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        //Get the amounts required for the swap to happen!
        uint256 amountRequired = IUniswapV2Router02(_router).getAmountsOut(_amountIn, path)[1];

        //Performs Arbitrage -Swap for another token
        uint256 amountReceived = IUniswapV2Router02(_router).swapExactTokensForTokens(_amountIn, 
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
        IERC20(WETH).safeApprove(address(UNISWAP_ROUTER), MAX_INT);
        IERC20(DAI).safeApprove(address(UNISWAP_ROUTER), MAX_INT);
        IERC20(LINK).safeApprove(address(UNISWAP_ROUTER), MAX_INT);

        IERC20(WETH).safeApprove(address(SUSHISWAP_ROUTER), MAX_INT);
        IERC20(DAI).safeApprove(address(SUSHISWAP_ROUTER), MAX_INT);
        IERC20(LINK).safeApprove(address(SUSHISWAP_ROUTER), MAX_INT);

        //Get the factory address for the combined tokens. This is going to return the pair for _tokenToBorrow and
        //wBNB.
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(_tokenToBorrow, WETH);

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
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);  //This is going to call the upcoming uniswapV2Call funct
    }

    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external{
        //Ensure this request came from the contract (from the swap call)
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(token0, token1);

        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "The sender should match this contract");

        //Decode the data for calculating the repayment
        (address tokenBorrow, uint256 amount, address myAddress) = abi.decode(_data, (address, uint256, address));

        //Calculate the amount to repay at the end
        uint256 fee = ((amount * 3) / 197) + 1;
        uint256 amountToPay = amount + fee;

        //DO ARBITRAGE!!!

        //AmountIn (WETH) -> AmountOut  DAI), AmountIn DAI) -> AmountOut(LINK), AmountIn(LINK) -> AmountOut(WETH)
        //Pay BUSD back!
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;
        uint256 trade1ReceivedCoin = placeTrade(DAI, LINK, loanAmount, UNISWAP_FACTORY, UNISWAP_ROUTER);
        uint256 arbitrageResult = placeTrade(LINK, DAI, trade1ReceivedCoin, SUSHISWAP_FACTORY, SUSHISWAP_ROUTER);
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        //PAY YOURSELF FIRST!!!
        require(profitableTrade(arbitrageResult, amountToPay + tx.gasprice), "Trade was not profitable!");
        IERC20(tokenBorrow).transfer(myAddress, (arbitrageResult - (amountToPay + tx.gasprice)));

        //NOW PAY THE LOAN BACK!!!
        IERC20(tokenBorrow).transfer(pair, amountToPay);
    }
}
