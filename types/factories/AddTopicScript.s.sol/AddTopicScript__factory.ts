/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Contract,
  ContractFactory,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import type { Signer, ContractDeployTransaction, ContractRunner } from "ethers";
import type { NonPayableOverrides } from "../../common";
import type {
  AddTopicScript,
  AddTopicScriptInterface,
} from "../../AddTopicScript.s.sol/AddTopicScript";

const _abi = [
  {
    type: "function",
    name: "IS_SCRIPT",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "run",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;

const _bytecode =
  "0x6080604052600b8054764341a3f0a350c2428184a727bab86e16d4ba701801000161ff01600160b81b0319909116179055600c80546001600160a01b031916733eb08c166509638669e78d0c50c0f82a25bc8e4617905534801561006257600080fd5b50610b11806100726000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c8063c04062261461003b578063f8ccbf4714610045575b600080fd5b61004361006c565b005b600b546100589062010000900460ff1681565b604051901515815260200160405180910390f35b60405163c1978d1f60e01b815260206004820152601960248201527f5343524950545f52554e4e45525f505249564154455f4b4559000000000000006044820152600090737109709ecfa91a80626ff3989d68f67f5b1dd12d9063c1978d1f90606401602060405180830381865afa1580156100ec573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906101109190610773565b6040516001625e79b760e01b0319815260048101829052909150600090737109709ecfa91a80626ff3989d68f67f5b1dd12d9063ffa1864990602401602060405180830381865afa158015610169573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061018d919061078c565b60405163ce817d4760e01b815260048101849052909150737109709ecfa91a80626ff3989d68f67f5b1dd12d9063ce817d4790602401600060405180830381600087803b1580156101dd57600080fd5b505af11580156101f1573d6000803e3d6000fd5b505050506102346040518060400160405280601781526020017f42726f6164636173742073746172746564206279202573000000000000000000815250826106bd565b60006040518060e001604052806040518060400160405280601881526020017f41727420426c6f636b73204375726174656420496e646578000000000000000081525081526020016040518060400160405280600a8152602001690b2eacec24092dcc8caf60b31b8152508152602001604051806040016040528060098152602001680a08ca04092dcc8caf60bb1b81525081526020016040518060400160405280601f81526020017f546f70203330204c697175696420436f6c6c656374696f6e7320496e646578008152508152602001604051806040016040528060138152602001725975676120496e646578202d20477261696c7360681b8152508152602001604051806060016040528060218152602001610abb602191398152604080518082018252601281527150465020496e646578202d20477261696c7360701b602080830191909152928301528051600780825261010082019092529293506000929182015b6040805161012081018252606091810182815260008383018190526080830181905260a0830181905260c0830181905260e083018190526101008301528152602081019190915281526020019060019003908161039b579050506040805161010081018252600060e0820181815282526001600160a01b0387811660208401526001838501819052610e106060850152600c54909116608084015260a0830181905260c083018190528351818152808501909452939450909290919081602001602082028036833701905050905073a459c3a3b7769e18e702a3b5e2decdd49565579181600081518110610491576104916107d2565b6001600160a01b039092166020928302919091018201526040805180820190915283815290810182905260005b600781101561052d57818582815181106104da576104da6107d2565b60200260200101819052508581600781106104f7576104f76107d2565b602002015185828151811061050e5761050e6107d2565b6020908102919091010151515280610525816107e8565b9150506104be565b50600b54604051633a4bf68f60e21b8152600091630100000090046001600160a01b03169063e92fda3c90610566908890600401610899565b6000604051808303816000875af1158015610585573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f191682016040526105ad919081019061099c565b905060005b600781101561063c5761062a6040518060400160405280601b81526020017f546f706963202225732220616464656420776974682069642025730000000000815250888360078110610606576106066107d2565b602002015184848151811061061d5761061d6107d2565b6020026020010151610706565b80610634816107e8565b9150506105b2565b507f885cb69240a935d632d79c317109709ecfa91a80626ff3989d68f67f5b1dd12d60001c6001600160a01b03166376eadd366040518163ffffffff1660e01b8152600401600060405180830381600087803b15801561069b57600080fd5b505af11580156106af573d6000803e3d6000fd5b505050505050505050505050565b61070282826040516024016106d3929190610a5a565b60408051601f198184030181529190526020810180516001600160e01b031663319af33360e01b179052610752565b5050565b61074d83838360405160240161071e93929190610a84565b60408051601f198184030181529190526020810180516001600160e01b031663f362ca5960e01b179052610752565b505050565b80516a636f6e736f6c652e6c6f67602083016000808483855afa5050505050565b60006020828403121561078557600080fd5b5051919050565b60006020828403121561079e57600080fd5b81516001600160a01b03811681146107b557600080fd5b9392505050565b634e487b7160e01b600052604160045260246000fd5b634e487b7160e01b600052603260045260246000fd5b60006001820161080857634e487b7160e01b600052601160045260246000fd5b5060010190565b6000815180845260005b8181101561083557602081850181015186830182015201610819565b506000602082860101526020601f19601f83011685010191505092915050565b600081518084526020808501945080840160005b8381101561088e5781516001600160a01b031687529582019590820190600101610869565b509495945050505050565b60006020808301818452808551808352604092508286019150828160051b87010184880160005b8381101561098e57603f1989840301855281518051878552805160e0808a8801526108ef61012088018361080f565b838c01516001600160a01b03166060898101919091528b85015165ffffffffffff9081166080808c0191909152918601511660a08a8101919091529085015191935060c0610947818b01846001600160a01b03169052565b9085015115159289019290925250909101518015156101008701529091890151858303868b0152916109798184610855565b978a01979550505091870191506001016108c0565b509098975050505050505050565b600060208083850312156109af57600080fd5b825167ffffffffffffffff808211156109c757600080fd5b818501915085601f8301126109db57600080fd5b8151818111156109ed576109ed6107bc565b8060051b604051601f19603f83011681018181108582111715610a1257610a126107bc565b604052918252848201925083810185019188831115610a3057600080fd5b938501935b82851015610a4e57845184529385019392850192610a35565b98975050505050505050565b604081526000610a6d604083018561080f565b905060018060a01b03831660208301529392505050565b606081526000610a97606083018661080f565b8281036020840152610aa9818661080f565b91505082604083015294935050505056fe41727420426c6f636b73204375726174656420496e646578202d20477261696c73a2646970667358221220dc7f4897f217752120e72f79fe39d2e00aef416f88a2b4f4dc84e7d8c30cfd9e64736f6c63430008150033";

type AddTopicScriptConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: AddTopicScriptConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class AddTopicScript__factory extends ContractFactory {
  constructor(...args: AddTopicScriptConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(overrides || {});
  }
  override deploy(overrides?: NonPayableOverrides & { from?: string }) {
    return super.deploy(overrides || {}) as Promise<
      AddTopicScript & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): AddTopicScript__factory {
    return super.connect(runner) as AddTopicScript__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): AddTopicScriptInterface {
    return new Interface(_abi) as AddTopicScriptInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): AddTopicScript {
    return new Contract(address, _abi, runner) as unknown as AddTopicScript;
  }
}
