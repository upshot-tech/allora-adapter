import ethers from 'ethers'
import Deployer from './Deployer'

import { EvenFeeHandler__factory } from '../types/factories/EvenFeeHandler__factory'
import { MedianAggregator__factory } from '../types/factories/MedianAggregator__factory'
import { Prices__factory } from '../types/factories/Prices__factory'

const contractInfoMap = {
  'MedianAggregator': {
    path: 'src/aggregator/MedianAggregator.sol',
    connect: MedianAggregator__factory.connect
  },
  'EvenFeeHandler': {
    path: 'src/feeHandler/EvenFeeHandler.sol',
    connect: EvenFeeHandler__factory.connect
  },
  'Prices': {
    path: 'src/Prices.sol',
    connect: Prices__factory.connect
  },
}

const adminAddress = '0x0000000000000000000000000000000000000100'
const protolFeeReceiver = '0x0000000000000000000000000000000000000101'

const deploy = async () => {
  const deployer = new Deployer(contractInfoMap)

  const MedianAggregator = await deployer.deploy('MedianAggregator', [])
  const EvenFeeHandler = await deployer.deploy('EvenFeeHandler', [adminAddress, protolFeeReceiver])

  const medianAggregatorAddress = await MedianAggregator.getAddress()
  const evenFeeHandlerAddress = await EvenFeeHandler.getAddress()

  const Prices = await deployer.deploy('Prices', [adminAddress, medianAggregatorAddress, evenFeeHandlerAddress])

  // Example contract call post deployment
  /*
  await deployer.call(
    'Allow Exponential curve on Pair Factory',
    LSSVMPairFactory.setBondingCurveAllowed(ExponentialCurve.address, true),
    async () => await LSSVMPairFactory.bondingCurveAllowed(ExponentialCurve.address),
  )
  */
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })