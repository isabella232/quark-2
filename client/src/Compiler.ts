import type { Command } from './Command';

export type Compile = (input: string) => string | Promise<string>;

export interface ContractOutput {
  ir: string,
  evm: {
    bytecode: {
      object: string
    }
  }
}

interface CompilationError {
  component: string;
  formattedMessage: string;
  message:  string;
  severity:  string;
  sourceLocation: unknown,
  type: string;
}

export interface Output {
  errors?: CompilationError[],
  contracts: { [contract: string]: ContractOutput }
}

export async function buildSol(source: string, fnName: string, compile: Compile): Promise<Command> {
  if (source.includes('import')) {
    throw new Error('For experimental Solidity support, `import`s are not allowed');
  }

  let input = {
    language: 'Solidity',
    sources: {
      'q.sol': {
        content: source
      }
    },
    settings: {
      outputSelection: {
        'q.sol': {
          '*': ['ir']
        }
      }
    }
  };

  let res = JSON.parse(await compile(JSON.stringify(input))) as Output;

  let [ctxName, v] = Object.entries(res.contracts['q.sol'])[0];
  let irBase = v.ir;

  let regex = new RegExp(`(object "${ctxName}_\\d+_deployed" {.+})\\s*}\\s*`, 's');

  let regexMatch = regex.exec(irBase);

  if (!regexMatch) {
    throw new Error('Cannot currently handle Yul produced from .sol file [cannot find deployed contract]');
  }

  let innerObject = regexMatch[1];

  let fnMatch = innerObject.match(new RegExp(`\"function ${fnName}.*\\n\\s*function (\\w+)`));

  if (!fnMatch) {
    throw new Error(`Cannot currently handle Yul produced from .sol file [cannot find function "${fnName}"]`); 
  }

  let fnFullName = fnMatch[1];

  let replaceRegex = /code {.*?function/s;

  let codeStartMatch = innerObject.match(replaceRegex);

  if (!codeStartMatch) {
    throw new Error(`Cannot currently handle Yul produced from .sol file [cannot find function invocation to replace]`); 
  }

  let memoryguardMatch = codeStartMatch[0].match(/^.*memoryguard.*$/m);

  let lines = [
    '',
    'verbatim_0i_0o(hex"303030505050")',
    memoryguardMatch ? memoryguardMatch[0].trim() : '',
    `${fnFullName}()`,
    'return(0,0)',
    'function'
  ];

  let yul = innerObject.replace(replaceRegex, `code {${lines.join('\n            ')}`);

  return buildYul(yul, compile, `Solidity Source:\n\n${source}`);
}

export async function buildYul(yul: string, compile: Compile, description?: string): Promise<Command> {
  if (!yul.includes(`verbatim_0i_0o(hex"303030505050")`)) {
    // Let's try to insert verbatim for the user
    let insertVerbatimRegex = /^object\s*"\w+"\s*{\s*code\s*{/sm;
    if (yul.match(insertVerbatimRegex)) {
      let m = insertVerbatimRegex.exec(yul)
      let idx = m![0].length;
      yul = [yul.slice(0, idx), `\n    verbatim_0i_0o(hex"303030505050")`, yul.slice(idx)].join('');
    } else {
      throw new Error(`Please include \`verbatim_0i_0o(hex"303030505050")\` at the start of your Yul object.`);
    }
  }

  let input = {
    language: 'Yul',
    sources: {
      'q.yul': {
        content: yul
      }
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 1
      },
      evmVersion: "paris",
      outputSelection: {
        'q.yul': {
          '*': ['evm.bytecode.object']
        }
      }
    }
  };

  let yulCompilationRes = JSON.parse(await compile(JSON.stringify(input))) as Output;
  if (yulCompilationRes.errors && yulCompilationRes.errors.length > 0) {
    throw new Error(`Yul compilation error: ${yulCompilationRes.errors.map((e) => e.formattedMessage).join('\n\n')}`);
  }

  let bytecode = Object.values(yulCompilationRes.contracts['q.yul'])[0].evm.bytecode.object as string;

  if (!bytecode.startsWith('303030505050')) {
    throw new Error(`Invalid bytecode produced, does not start with magic incantation 0x303030505050, got: ${bytecode}`);
  }

  return {
    yul,
    description: description ?? `Yul source\n\n${yul}`,
    bytecode: `0x` + bytecode
  };
}
