const { ethers } = require("ethers");
const { abi : QuoterABI } = require('@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json');
const { abi : IUniswapV3PoolABI } = require('@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json');
const { Token } = require("@uniswap/sdk-core");
const {factoryABI, erc20ABI} = require("./GetABIs");
const provider = new ethers.providers.JsonRpcProvider('https://eth-mainnet.alchemyapi.io/v2/fo_13A_yj2TcDjpwJ1Y7s2mnfAVJSxYR');


async function getPrice (addressFrom, addressTo, amountInHuman){
    //Get the pool address from the Uniswap Factory contract
    const factoryAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    const factoryContract = new ethers.Contract(factoryAddress, factoryABI, provider);

    //Get the pool's address so that we can get its fee
    const poolAddress = await factoryContract.getPool(addressFrom, addressTo, 3000);
    const poolContract = new ethers.Contract(poolAddress, IUniswapV3PoolABI, provider);

    //Get the quoter contract for the swap's price quote
    const quoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";
    const quoterContract = new ethers.Contract(quoterAddress, QuoterABI, provider);

    const token0Contract = new ethers.Contract(addressFrom, erc20ABI, provider);
    const tokenDecimal = await token0Contract.decimals();
    const amountIn = ethers.utils.parseUnits(amountInHuman, tokenDecimal);

    //Get the swap price quote
    const quotedAmountOut = await quoterContract.callStatic.quoteExactInputSingle(addressFrom,
        addressTo,
        poolContract.fee(),
        amountIn.toString(),
        0);
    
    //Output the swap price quote in human-readable form
    const quotedOutHuman = ethers.utils.formatUnits(quotedAmountOut.toString(), 18);
    return(quotedOutHuman);
}

const main = async () => {
    //USDC to wETH
    const usdcAddr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const amountIn = "2003";

    const amountOut = await getPrice(usdcAddr, wethAddr, amountIn);

    console.log(amountOut);
}

main();
