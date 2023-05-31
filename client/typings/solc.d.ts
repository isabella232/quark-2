
// TODO: Make solc compilation async?
declare module 'solc' {
  export function compile(input: string): string

  export interface ContractOutput {
    ir: string,
    evm: {
      bytecode: {
        object: string
      }
    }
  }

  export interface Output {
    contracts: { [contract: string]: ContractOutput }
  }
}