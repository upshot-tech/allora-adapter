// SPDX-License-Identifier: BUSL-1.1

import { UpshotAdapter__factory } from '../types/factories/UpshotAdapter__factory'
import { UpshotAdapter } from '../types/UpshotAdapter';
import { ethers, BigNumberish, BytesLike } from 'ethers';
import * as dotenv from 'dotenv';

// to run: ts-node script/verifyDataExample.ts

const UPSHOT_ADAPTER_NAME = 'UpshotAdapter'
const UPSHOT_ADAPTER_VERSION = 1
const UPSHOT_ADAPTER_ADDRESS = '0x238D0abD53fC68fAfa0CCD860446e381b400b5Be'
const UPSHOT_ADAPTER_CHAIN_ID = 11155111

type NumericDataStruct = {
  topicId: BigNumberish
  timestamp: BigNumberish
  numericValue: BigNumberish
  extraData: BytesLike
};

// hex string of the format '0xf9a0b2c3...'
const hexStringToByteArray = (rawHexString: string) => {
  const hexString = rawHexString.substring(2);
  const chunkedArray: string[] = []
  for (let i = 0; i < hexString.length; i += 2) {
    chunkedArray.push(hexString.substring(i, i + 2));
  }
  const bytesOfMessage = chunkedArray.map(chunk => parseInt(chunk, 16));
  return new Uint8Array(bytesOfMessage);
}

const constructMessageLocally = async (
  numericData: NumericDataStruct, 
  config: {
    chainId: number,
    upshotAdapterAddress: string,
  }
) => {
  const keccak = ethers.keccak256
  const coder = new ethers.AbiCoder()
  const toBytes = ethers.toUtf8Bytes

  const { chainId, upshotAdapterAddress } = config

  const numericDataTypehash = keccak(toBytes('NumericData(uint256 topicId,uint256 timestamp,uint256 numericValue,bytes extraData)'))

  const domainSeparator = keccak(coder.encode(
    ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
    [
      keccak(toBytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
      keccak(toBytes(UPSHOT_ADAPTER_NAME)),
      keccak(toBytes(UPSHOT_ADAPTER_VERSION.toString())),
      chainId.toString(),
      upshotAdapterAddress,
    ]
  ))

  const intermediateHash = keccak(coder.encode(
    ['bytes32', 'uint256', 'uint256', 'uint256', 'bytes'],
    [
      numericDataTypehash,
      numericData.topicId, 
      numericData.timestamp, 
      numericData.numericValue, 
      numericData.extraData
    ]
  ))

  return keccak(
    ethers.solidityPacked(
      ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
      ['0x19', '0x01', domainSeparator, intermediateHash]
    )
  )
}

const signMessageLocally = async (
  numericData: NumericDataStruct, 
  config: {
    chainId: number
    upshotAdapterAddress: string
    privateKey: string
  }
) => {
  const { chainId, upshotAdapterAddress, privateKey } = config
  const wallet = new ethers.Wallet(privateKey)

  const message = await constructMessageLocally(
    numericData, 
    { chainId, upshotAdapterAddress }
  )
  const messageBytes = hexStringToByteArray(message)

  return await wallet.signMessage(messageBytes)

}

const run = async () => {
  dotenv.config()

  const privateKey = getEnvVariable('privateKey')
  const rpcUrl = getEnvVariable('rpcUrl')

  const provider = new ethers.JsonRpcProvider(rpcUrl)
  const wallet = new ethers.Wallet(privateKey, provider)

  const upshotAdapter = (new UpshotAdapter__factory()).attach(UPSHOT_ADAPTER_ADDRESS).connect(wallet) as UpshotAdapter

  const numericData: NumericDataStruct = {
    topicId: 1,
    timestamp: Math.floor(Date.now() / 1000) - (60 * 5),
    numericValue: '123456789012345678',
    extraData: ethers.toUtf8Bytes(''),
  }

  console.info('verifying numericData')
  console.info({numericData})

  const message = await upshotAdapter.getMessage(numericData)
  const messageBytes = hexStringToByteArray(message)

  // sign the message with the private key
  const signature = await wallet.signMessage(messageBytes)
  const localSignature = await signMessageLocally(numericData, { 
    chainId: UPSHOT_ADAPTER_CHAIN_ID,
    upshotAdapterAddress: UPSHOT_ADAPTER_ADDRESS, 
    privateKey 
  })

  console.log({signature, localSignature})

  if (signature !== localSignature) {
    throw new Error('local signature does not match remote. Check chainId.')
  }

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

const main = async () => {
  console.info('STARTING')
  await run()
  console.info('COMPLETE')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('ERROR')
    console.error(error)
    process.exit(1)
  })