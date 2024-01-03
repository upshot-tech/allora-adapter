// SPDX-License-Identifier: BUSL-1.1

import { UpshotAdapter__factory } from '../types/factories/UpshotAdapter__factory'
import { NumericDataStruct, UpshotAdapter } from '../types/UpshotAdapter'
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

const UPSHOT_ADAPTER_ADDRESS = '0x238D0abD53fC68fAfa0CCD860446e381b400b5Be'

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
    timestamp: 1704318000, // Math.floor(Date.now() / 1000) - (60 * 5),
    numericValue: '123456789012345678',
    extraData: ethers.toUtf8Bytes(''),
  }

  const message = await upshotAdapter.getMessage(numericData)

  const hexString = message.substring(2);
  const chunkedArray: string[] = []
  for (let i = 0; i < hexString.length; i += 2) {
    chunkedArray.push(hexString.substring(i, i + 2));
  }
  const bytesOfMessage = chunkedArray.map(chunk => parseInt(chunk, 16));
  const byteArray = new Uint8Array(bytesOfMessage);

  // sign the message with the private key
  const signature = await wallet.signMessage(byteArray)
  console.log({message, bytesOfMessage, hexString, byteArray, signature})

  await upshotAdapter.verifyData({
    signedNumericData:[{ signature, numericData }],
    extraData: ethers.toUtf8Bytes(''),
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