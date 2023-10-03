// SPDX-License-Identifier: BUSL-1.1

import fs from 'fs'
import { ContractTransaction, Wallet, ContractFactory, JsonRpcProvider } from 'ethers'
import { execSync, exec } from 'child_process'
import * as dotenv from 'dotenv';
import axios from 'axios'

type deploymentRecord = {[contractId in string]: string}

type PromiseType<T> = T extends Promise<infer U> ? U : T;

type contractInfoMap = { 
  [contractName: string]: { 
    path: string 
    factory: ContractFactory
    libraries?: string[]
  }
}

const chainIdToNetworkName: {[chainId in number]: string} = {
  1: 'mainnet',
  3: 'ropsten',
  4: 'rinkeby',
  5: 'goerli',
  42: 'kovan',
  11155111: 'sepolia'
}

class Deployer <contractInfo extends contractInfoMap>{
  deploymentRecordPath: string
  rpcUrl: string
  privateKey: string
  wallet: Wallet
  contractInfoMap: contractInfo
  etherscanApiKey: string
  chainId: number

  deploymentRecord: deploymentRecord = {}

  constructor(contractInfoMap: contractInfo) {
    dotenv.config()

    this.deploymentRecordPath = `${__dirname}/deployments/${Deployer.getEnvVariable('deploymentName')}.json`
    this.rpcUrl = Deployer.getEnvVariable('rpcUrl')
    this.privateKey = Deployer.getEnvVariable('privateKey')
    this.etherscanApiKey = Deployer.getEnvVariable('etherscanApiKey')
    this.chainId = parseInt(Deployer.getEnvVariable('chainId'))

    this.wallet = new Wallet(this.privateKey, new JsonRpcProvider(this.rpcUrl))
    this.contractInfoMap = 
      Object.fromEntries(
        Object.entries(contractInfoMap).map(
          ([contractName, contractInfo]) => [contractName, {...contractInfo, factory: contractInfo.factory.connect(this.wallet)}])) as contractInfo

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

  public deploy = async<
    contractName extends keyof contractInfo, 
    argsType extends Parameters<contractInfo[contractName]["factory"]["deploy"]>,
    returnType extends PromiseType<ReturnType<contractInfo[contractName]["factory"]["deploy"]>>
  >(
    contractName: contractName,
    args: argsType,
  ): Promise<returnType> => {

    const contractId = `${this.contractInfoMap[contractName].path}:${String(contractName)}`
    const existingContractAddress = this.getDeployedContractAddress(String(contractName))

    const verify = async (contractAddress: string) => {
      console.info(`⏳ verifying ${String(contractName)}...`)
      const encodedArgs = this.contractInfoMap[contractName].factory.interface.encodeDeploy(args)
      await this.verifyContractUntilSuccess(contractAddress, contractId, this.etherscanApiKey, encodedArgs)
      console.info(`✅ VERIFIED ${contractId.split(':')[1]}`)
    }

    let contractAddress = ''
    if (existingContractAddress !== null) {
      console.info(`✅ ${String(contractName)} already deployed at ${existingContractAddress}`)
      contractAddress = existingContractAddress

      if (await this.isContractVerified(contractAddress)) {
        console.info(`✅ ${String(contractName)} already verified`)
      } else {
        await verify(contractAddress)
      }

      return this.contractInfoMap[contractName].factory.attach(contractAddress) as returnType
    }

    const contractInstance = await this.contractInfoMap[contractName].factory.deploy(...args)
    
    contractAddress = await contractInstance.getAddress()

    this.setDeployedContractAddress(String(contractName), contractAddress)
    console.info(`✅ DEPLOYED ${String(contractName)} to: ${contractAddress}`)

    await verify(contractAddress)

    return this.contractInfoMap[contractName].factory.attach(contractAddress) as returnType
  }

  private isContractVerified = async(contractAddress: string): Promise<boolean> => {
    try {
      const apiUrl = 
        this.chainId === 1
          ? 'https://api.etherscan.io/api'
          : `https://api-${chainIdToNetworkName[this.chainId]}.etherscan.io/api`

      const response = await axios.get(
        `${apiUrl}?module=contract&action=getabi&address=${contractAddress}&apikey=${this.etherscanApiKey}`
      )
      
      // If true, contract ABI is available, which means the contract is verified
      return response.data.status === '1' && response.data.message === 'OK'
    } catch (error) {
      console.error('Error checking contract verification:', error)
      return false
    }
  }

  private verifyContractUntilSuccess = async(
    address: string,
    contractId: string,
    apiKey: string,
    args: any
  ) => {
    return new Promise((resolve, _) => {
      const command = [
        `forge verify-contract ${address} ${contractId}`,
        `--chain ${this.chainId}`,
        `--etherscan-api-key ${apiKey}`,
        `--constructor-args ${args}`,
      ]

      const attemptVerification = () => {
        exec(command.join(' '), (error, stdout, stderr) => {
          if (error) {
            console.error(`Retrying after verification error: ${error}`)
            setTimeout(attemptVerification, 1000) // Try again after 1 second
            return
          }

          // Check if the output indicates success
          if (stdout.includes("OK") || stdout.includes("is already verified")) {
            resolve('OK')
            return
          } 

          // stdout contains the output of the command
          if (stderr) {
            console.error(`stderr: ${stderr}`)
          }

          setTimeout(attemptVerification, 1000) // Try again after 1 second
        })
      }
      attemptVerification();
    });
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

  public getDeployerAddress = () => this.wallet.address

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