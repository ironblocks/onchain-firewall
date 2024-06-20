import { HardhatUserConfig, task } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import 'solidity-coverage';

import testsRunnerTask from './tasks/test-runner.task';
task(testsRunnerTask.name, testsRunnerTask.description).setAction(testsRunnerTask.action);

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.24',
        settings: {
            optimizer: {
                enabled: true,
                runs: 10000,
            },
        },
    },
};

export default config;
