// SPDX-License-Identifier: BUSL-1.1

import { UpshotAdapter__factory } from '../types/factories/UpshotAdapter__factory'
import { UpshotAdapter } from '../types/UpshotAdapter'
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

const UPSHOT_ADAPTER_ADDRESS = '0xdD3C703221c7F00Fe0E2d8cdb5403ca7760CDd4c'
const ETH_PRICE_FEED_TOPIC = 2
const DUMMY_PRIVATE_KEY = '0x0123456789012345678901234567890123456789012345678901234567890123'


const run = async () => {
  dotenv.config()

  const provider = new ethers.JsonRpcProvider(getEnvVariable('rpcUrl'))
  const wallet = new ethers.Wallet(DUMMY_PRIVATE_KEY, provider)

  const upshotAdapter = (new UpshotAdapter__factory()).attach(UPSHOT_ADAPTER_ADDRESS).connect(wallet) as UpshotAdapter
  const result = await upshotAdapter.getTopic(ETH_PRICE_FEED_TOPIC)
  console.info({
    value: result.config.recentValue,
    timestamp: result.config.recentValueTime,
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