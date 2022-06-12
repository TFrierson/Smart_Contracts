//SPDX-License-Identifier: GPL-30
pragma solidity >= 0.7.0 < 0.9.0;

interface IUniswapV2Factory{
        function getPair(address tokenA, address tokenB) external view returns (address pair);
    }

interface IUniswapV2Pair{
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract UniswapPair1{
    address factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address tether = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    function getPairReserves() public view returns(uint, uint){
        address pair = IUniswapV2Factory(factory).getPair(tether, uni);
        (uint reserveA, uint reserveB,) = IUniswapV2Pair(pair).getReserves();
        return(reserveA, reserveB);
    }
}
