// SPDX-License-Identifier: BUSL-1.1

import { Oracle__factory } from '../types/factories/Oracle__factory'
import { Oracle } from '../types/Oracle'
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

const ORACLE_ADDRESS = '0x091Db6CB55773F6D60Eaffd0060bd79021A5F6A2'
const ETH_PRICE_FEED_TOPIC = 2
const DUMMY_PRIVATE_KEY = '0x0123456789012345678901234567890123456789012345678901234567890123'

const run = async () => {
  dotenv.config()

  const provider = new ethers.JsonRpcProvider(getEnvVariable('rpcUrl'))
  const wallet = new ethers.Wallet(DUMMY_PRIVATE_KEY, provider)

  const oracle = (new Oracle__factory()).attach(ORACLE_ADDRESS).connect(wallet) as Oracle
  const result = await oracle.getTopic(ETH_PRICE_FEED_TOPIC)
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