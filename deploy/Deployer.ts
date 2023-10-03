// Copyright (c) 2020-2022. All Rights Reserved
// SPDX-License-Identifier: UNLICENSED

import fs from 'fs'
import { ContractTransaction, Wallet, ContractRunner, JsonRpcProvider } from 'ethers'
import { execSync } from 'child_process'
import * as dotenv from 'dotenv';

type deploymentRecord = {[contractId in string]: string}

type contractInfoMap = { 
  [contractName: string]: { 
    path: string 
    connect: (address: string, signerOrProvider: ContractRunner) => any
    libraries?: string[]
  }
}

class Deployer <contractInfo extends contractInfoMap>{
  deploymentRecordPath: string
  rpcUrl: string
  privateKey: string
  wallet: Wallet
  contractInfoMap: contractInfo
  etherscanApiKey?: string

  deploymentRecord: deploymentRecord = {}

  constructor(contractInfoMap: contractInfo) {
    dotenv.config()

    this.deploymentRecordPath = `${__dirname}/deployments/${Deployer.getEnvVariable('deploymentName')}.json`
    this.rpcUrl = Deployer.getEnvVariable('rpcUrl')
    this.privateKey = Deployer.getEnvVariable('privateKey')
    this.etherscanApiKey = Deployer.getOptionalEnvVariable('etherscanApiKey')

    this.wallet = new Wallet(this.privateKey, new JsonRpcProvider(this.rpcUrl))
    this.contractInfoMap = contractInfoMap

    if (fs.existsSync(this.deploymentRecordPath)) {
      this.deploymentRecord = JSON.parse(fs.readFileSync(this.deploymentRecordPath, 'utf8')) as deploymentRecord
    } else {
      this.initializeData()
    }
  }

  // ================ Internal =================
  private writeDeploymentRecord = () => fs.writeFileSync(this.deploymentRecordPath, JSON.stringify(this.deploymentRecord))

  private initializeData = () => {
    this.deploymentRecord = {}
    this.writeDeploymentRecord()
  }

  private setDeployedContractAddress = (contractName: string, address: string) => {
    this.deploymentRecord[contractName] = address
    this.writeDeploymentRecord()
  }

  // ================ External =================
  public getDeployedContractAddress = (contractName: string): string | null => {
    return this.deploymentRecord.hasOwnProperty(contractName) ? this.deploymentRecord[contractName] : null
  }

  public clearDeployedContractAddresses = () => {
    this.initializeData()
  }

  /* 
    Executes the forge create cli command, an example of which is listed below.

    forge create --rpc-url <your_rpc_url> \
      --constructor-args "ForgeUSD" "FUSD" 18 1000000000000000000000 \
      --private-key <your_private_key> src/MyToken.sol:MyToken \
      --etherscan-api-key <your_etherscan_api_key> \
      --verify
  */
  public deploy = async<contractName extends keyof contractInfo>(
    contractName: contractName,
    args: (string | number)[], // TODO infer this from the SpecificContractFactory 
  ): Promise<ReturnType<contractInfo[contractName]["connect"]>> => {

    const contractId = `${this.contractInfoMap[contractName].path}:${String(contractName)}`
    const existingContractAddress = this.getDeployedContractAddress(String(contractName))
    if (existingContractAddress !== null) {
      console.info(`☑️  ${String(contractName)} already deployed at ${existingContractAddress}`)
      return this.contractInfoMap[contractName].connect(existingContractAddress, this.wallet) 
    }

    const constructorArgs = 
      args.length === 0
        ? ''
        : '--constructor-args ' + args.map(arg => typeof arg === 'string' ? `"${arg}"` : arg).join(' ')

    const libraries = this.contractInfoMap[contractName].libraries

    const libraryArgs = 
      libraries !== undefined && libraries.length > 0
        ? '--libraries ' + libraries.map(lib => {
            if (this.deploymentRecord.hasOwnProperty(lib)) {
              return `${this.contractInfoMap[lib].path}:${lib}:${this.deploymentRecord[lib]}`
            } else {
              throw new Error(`Library ${lib} not yet deployed for contract ${contractId}`)
            }
          }).join(' ')
        : ''

    const etherscanArgs = 
      this.etherscanApiKey === undefined 
        ? ''
        : `--etherscan-api-key ${this.etherscanApiKey} --verify`

    const command = [
      `forge create`,
      `--rpc-url ${this.rpcUrl}`,
      constructorArgs,
      libraryArgs,
      `--private-key ${this.privateKey}`,
      `${contractId}`,
      etherscanArgs
    ]

    console.info(`⏳ deploying ${String(contractName)}...`)

    const deployCommandOutput = execSync(command.join(' ')).toString()

    const contractAddressIndex = deployCommandOutput.indexOf('0x', deployCommandOutput.indexOf('Deployed to: '))
    const contractAddress = deployCommandOutput.substring(contractAddressIndex, contractAddressIndex + 42)
    this.setDeployedContractAddress(String(contractName), contractAddress)
    console.info(`✅ DEPLOYED ${String(contractName)} to: ${contractAddress}`)

    return this.contractInfoMap[contractName].connect(contractAddress, this.wallet) 
  }

  public call = async (
    callName: string,
    call: Promise<ContractTransaction>,
    callAlreadyComplete: () => Promise<boolean>
  ) => {
    if (await callAlreadyComplete()) {
      console.info(`☑️  ${callName} already complete`)
    } else {
    console.info(`⏳ executing ${callName}...`)
      const result = await call
      console.info(`✅ ${callName} complete`)
      return result
    }
  }

  // ================ Static Helper =================
  static getOptionalEnvVariable = (name: string): string | undefined => process.env[name]

  static getEnvVariable = (name: string) => {
    const envVar = this.getOptionalEnvVariable(name)
    if (envVar === undefined) {
      throw new Error(`Environment variable ${name} not defined.`)
    }
    return envVar
  }
}

export default Deployer