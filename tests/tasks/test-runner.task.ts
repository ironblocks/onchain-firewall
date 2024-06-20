import { Glob } from 'glob';
import path from 'path';

import type { HardhatRuntimeEnvironment, RunSuperFunction } from 'hardhat/types';
import type { TaskArguments } from 'hardhat/types';

async function runTests(
    _taskArgs: TaskArguments,
    _hre: HardhatRuntimeEnvironment,
    runSuper: RunSuperFunction<TaskArguments>
) {
    const glob = new Glob('**/*.test.ts', {
        ignore: [
            '**/node_modules/**',
            '**/artifacts/**',
            '**/coverage/**',
            '**/dist/**',
            '**/typechain-types/**',
            '**/contracts/**',
            '**/tasks/**',
        ],
    });

    const testFiles = glob.walkSync().map((file) => path.resolve(file));
    await runSuper({ testFiles });
}

export default {
    name: 'test',
    description: 'Runs tests',
    action: runTests,
};
