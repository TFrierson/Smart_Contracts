pragma solidity >= 0.7.0;
pragma abicoder v2;

import "hardhat/console.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

contract MultihopSwap {
    using SafeERC20 for IERC20;  //Swap approvals
    ISwapRouter public immutable swapRouter;

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

    function swapExactInputMultihop(address _fromToken, address _toToken1, address _toToken2, uint256 amountIn) external returns(uint256 amountOut){
        //msg.sender must approve this contract
        //TransferHelper's safeapprove does not work!

        //Approve the router to spend the tokens
        IERC20(_fromToken).safeApprove(address(swapRouter), amountIn);

        /*To execute the swap function, we must populate the ExactInputSingleParams with the
          necessary swap data*/

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(_fromToken, poolFee, _toToken1, poolFee, _toToken2),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });

        amountOut = swapRouter.exactInput(params);       //This executes the swap
    }
}
