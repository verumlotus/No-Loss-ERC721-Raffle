# No-Loss NFT Raffle

No-loss NFT raffle that deposits user funds into a yield-bearing strategy and forwards all interest to NFT creator.

## Background
Traditional auctions & raffles require users to deposit money that is not returned to them. [Premium Bond](https://en.wikipedia.org/wiki/Premium_Bond) inspired mechanisms (such as [PoolTogether](https://pooltogether.com/)) allow users to participate in a lottery with the ability to redeem their original deposit, regardless of whether they win. The `NFTRaffle.sol` contract in this repo contains similar logic for NFTs. An NFT creator is able to raffle off their NFT, collecting the interest generated from depositor's tokens during the raffle period. [Chainlink's VRF](https://docs.chain.link/docs/chainlink-vrf/) mechanism is leveraged to fairly determine a user at random (weighted by the size of their deposit). 

<img width="1096" alt="image" src="https://user-images.githubusercontent.com/97858468/170575435-624da5e9-f515-42ec-a3a9-584efe79d441.png">


Traditional auctions & raffles require users to deposit money that is not returned to them. [Premium Bond](https://en.wikipedia.org/wiki/Premium_Bond) inspired mechanisms (such as [PoolTogether](https://pooltogether.com/)) allow users to participate in a lottery with the ability to redeem their original deposit, regardless of whether they win. The `NFTRaffle.sol` contract in this repo contains similar logic for NFTs. An NFT creator is able to raffle off their NFT, collecting the interest generated from depositor's tokens during the raffle period. [Chainlink's VRF](https://docs.chain.link/docs/chainlink-vrf/) mechanism is leveraged to fairly determine a user at random (weighted by the size of their deposit). 

## Flow for an NFT Raffler
- Acquires a Chainlink VRF Subscription Account and funds it with LINK token (see Chainlink docs [here](https://docs.chain.link/docs/chainlink-vrf/)
- Configures settings and deploys contract, adding the deployed contract address as a authorized Chainlink Consumer to the subscription account created above
- Escrows the NFT in the contract via `depositNFT`
- After the user deposit period is over, calls `investRaffleDeposits` to invest raffle deposits into a yield-bearing strategy (currently Yearn)
- After the interest generation period is over, calls `withdrawRaffleDepositsFromYearn` to withdraw the original yearn deposit along with interest. The interest generated is automatically transferred to the owner. 

## Flow for a user
- Calls `enterRaffle` with a specified amount of tokens to enter the raffle
- After the interest generation period is over, anyone can invoke `requestRandomWords`, which will trigger the chainlink VRF process to kick off
- The Chainlink VRF coordinator will invoke the `fulfillRandomWords` callback, which will randomly assign a winner
- All users can withdraw their original deposit via `withdrawRaffleDeposit`
- The winner can claim the NFT via `claimWinner`

## Build & Testing
This repo uses Foundry for both the build and testing flows. Run `forge build` to build the repo and `forge test` for tests.

## Improvements
This contract assumes that the interst-bearing strategy will return a positive interest, which is not always the case. A future iteration can be made more robust to account for a loss of funds and handle business logic accordingly. This contract is a prototype, and has not been gas-optimized either. 

## Acknowledgements
Part of this idea was inspired by [PoolTogether](https://pooltogether.com/) and they work they have done with their no-loss loterry. 

## Disclaimer
This was a minimal implementation created for personal uses and for fun, and should not be used in production.

