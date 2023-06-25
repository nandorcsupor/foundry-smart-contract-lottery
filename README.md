# Random Lottery Contract

## Overview
This code creates a proveably random smart contract lottery

# What we want it to do ?

1. Users can enter by paying for a ticket
    1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
    1. The winner will be chosen randomly
    2. The winner will receive all the money in the contract
3. The lottery will then reset and start again

3. Using Chainlink VRF & Chainlink Automation


## Tests!

1. Write some deploy scripts
2. Write our tests
    1. Work on a local chain
    2. Forked Testnet
    3. Forked Mainnet

# Run test with logs
forge test -vvvvv

# Install new library:
- forge install transmissions11/solmate --no-commit




