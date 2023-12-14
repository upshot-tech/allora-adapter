// SPDX-License-Identifier: BUSL-1.1

import { UpshotAdapter__factory } from '../types/factories/UpshotAdapter__factory'
import { NumericDataStruct, UpshotAdapter } from '../types/UpshotAdapter'
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

const UPSHOT_ADAPTER_ADDRESS = '0x766662c5078515A9D22A71ab695206aCD18dD44C'

const run = async () => {
  dotenv.config()

  const privateKey = getEnvVariable('privateKey')
  const rpcUrl = getEnvVariable('rpcUrl')

  console.log({privateKey, rpcUrl})

  const provider = new ethers.JsonRpcProvider(rpcUrl)
  const wallet = new ethers.Wallet(privateKey, provider)
  console.log({walletAddress: wallet.address})

  const upshotAdapter = (new UpshotAdapter__factory()).attach(UPSHOT_ADAPTER_ADDRESS).connect(wallet) as UpshotAdapter
  const priceFeed = await upshotAdapter.getTopic(1)

  console.log({priceFeed})

  const numericData: NumericDataStruct = {
    topicId: 1,
    timestamp: Math.floor(Date.now() / 1000) - (60 * 5),
    numericValue: '123456789012345678',
    extraData: '0x',
  }

  const message = await upshotAdapter.getMessage(numericData)

  // sign the message with the private key
  const signature = await wallet.signMessage(message)

  await upshotAdapter.verifyData({
    signedNumericData:[{ signature, numericData }],
    extraData: '0x',
  }, {
    gasLimit: 1e16
  })
}

const getEnvVariable = (name: string) => {
  const envVar = process.env[name]
  if (envVar === undefined) {
    throw new Error(`Environment variable ${name} not defined.`)
  }
  return envVar
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })