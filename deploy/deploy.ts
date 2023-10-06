// SPDX-License-Identifier: BUSL-1.1
import Deployer from './Deployer'

import { EvenFeeHandler__factory } from '../types/factories/EvenFeeHandler__factory'
import { MedianAggregator__factory } from '../types/factories/MedianAggregator__factory'
import { Prices__factory } from '../types/factories/Prices__factory'

const contractInfoMap = {
  'MedianAggregator': {
    path: 'src/aggregator/MedianAggregator.sol',
    factory: new MedianAggregator__factory()
  },
  'EvenFeeHandler': {
    path: 'src/feeHandler/EvenFeeHandler.sol',
    factory: new EvenFeeHandler__factory()
  },
  'Prices': {
    path: 'src/Prices.sol',
    factory: new Prices__factory()
  },
}

const ADMIN = '0xA62c64Ec38d4b280192acE99ddFee60768C51562'
const PROTOCOL_FEE_RECIEVER = '0x3205695cC930A983eCba4739cf24B6862F99092B'

const deploy = async () => {
  const deployer = new Deployer(contractInfoMap)

  const MedianAggregator = await deployer.deploy('MedianAggregator', [])
  const EvenFeeHandler = await deployer.deploy('EvenFeeHandler', [{admin: ADMIN, protocolFeeReceiver: PROTOCOL_FEE_RECIEVER}])

  const Prices = await deployer.deploy('Prices', [{
    admin: ADMIN, 
  }])

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