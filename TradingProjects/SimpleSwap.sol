//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0;
pragma abicoder v2;

import "hardhat/console.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import "./libraries/Address.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";

contract BasicSwap{
    using SafeERC20 for IERC20;  //Swap approvals
    ISwapRouter public immutable swapRouter;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    //Set the pool's fee to 0.3%
    uint24 poolFee = 3000;

    constructor(ISwapRouter _swapRouter){
        swapRouter = _swapRouter;
    }

    function fundSwapContract(address _owner, address _token, uint256 _amount) public{
         IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    //Get this contract's balance
    function getBalanceOfToken(address _address) public view returns(uint256){
        return IERC20(_address).balanceOf(address(this));
    }

    /*The caller must approve the contract to withdraw the tokens from the calling address'
      account to execute a swap. We must approve the Uniswap protocol router contract to
      use the tokens that our contract will be in possession of after they have been
      withdrawn from the calling address. Then, transfer the "amount" of DAI from the calling
      address into our contract, and use "amount" as the value passed to the second "approve"*/

    function swapExactInputSingle(uint256 amountIn) external returns(uint256 amountOut){
        //msg.sender must approve this contract
        //TransferHelper's safeapprove does not work!

        //Approve the router to spend the DAI
        IERC20(DAI).safeApprove(address(swapRouter), amountIn);

        /*To execute the swap function, we must populate the ExactInputSingleParams with the
          necessary swap data*/

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);       //This executes the swap
    }
}
