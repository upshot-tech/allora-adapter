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

  //////////////////////////////////////////////////////////
  //////////////////// DEPLOY SUDOSWAP /////////////////////
  //////////////////////////////////////////////////////////
  // deploy pair templates
  const MedianAggregator = await deployer.deploy('MedianAggregator', [])
  const EvenFeeHandler = await deployer.deploy('EvenFeeHandler', [{
      admin: adminAddress,
      protolFeeReceiver: protolFeeReceiver
  }])

  /*
  const LSSVMPairMissingEnumerableETH = await deployer.deploy('LSSVMPairMissingEnumerableETH', [])
  const LSSVMPairEnumerableERC20 = await deployer.deploy('LSSVMPairEnumerableERC20', [])
  const LSSVMPairMissingEnumerableERC20 = await deployer.deploy('LSSVMPairMissingEnumerableERC20', [])

  // deploy factory
  const LSSVMPairFactory = await deployer.deploy(
    'LSSVMPairFactory', 
    [
      LSSVMPairEnumerableETH.address,
      LSSVMPairMissingEnumerableETH.address,
      LSSVMPairEnumerableERC20.address,
      LSSVMPairMissingEnumerableERC20.address,
      Deployer.getEnvVariable('feeRecipient'),
      ethers.parseEther('0.01').toString(),
    ]
  )

  // deploy router
  const LSSVMRouter = await deployer.deploy('LSSVMRouter', [LSSVMPairFactory.address])

  // Whitelist router in factory
  await deployer.call(
    'Allow LSSVMRouter on Pair Factory',
    LSSVMPairFactory.setRouterAllowed(LSSVMRouter.address, true),
    async () => { 
      const status = await LSSVMPairFactory.routerStatus(LSSVMRouter.address)
      return status.allowed
    }
  )

  // deploy bonding curves
  const ExponentialCurve = await deployer.deploy('ExponentialCurve', [])
  const LinearCurve = await deployer.deploy('LinearCurve', [])

  // Whitelist bonding curves in factory
  await deployer.call(
    'Allow Exponential curve on Pair Factory',
    LSSVMPairFactory.setBondingCurveAllowed(ExponentialCurve.address, true),
    async () => await LSSVMPairFactory.bondingCurveAllowed(ExponentialCurve.address),
  )
  await deployer.call(
    'Allow Linear curve on Pair Factory',
    LSSVMPairFactory.setBondingCurveAllowed(LinearCurve.address, true),
    async () => await LSSVMPairFactory.bondingCurveAllowed(LinearCurve.address),
  )

  const admin = Deployer.getEnvVariable('admin')

  // Transfer factory ownership to admin
  await deployer.call(
    'Transfer Pair Factory ownership to admin',
    LSSVMPairFactory.transferOwnership(admin),
    async () => {
      const owner = await LSSVMPairFactory.owner()
      return owner === admin
    },
  )

  //////////////////////////////////////////////////////////
  /////////////////// DEPLOY UPSHOTSWAP ////////////////////
  //////////////////////////////////////////////////////////
  const MetadataGenerator = await deployer.deploy('MetadataGenerator', [])
  const UpshotPoolFactory = await deployer.deploy('UpshotPoolFactory', [LSSVMPairFactory.address])
  */
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })