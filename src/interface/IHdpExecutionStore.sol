// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {ComputationalTask} from "lib/hdp-solidity/src/datatypes/datalake/ComputeCodecs.sol";
import {ModuleTask} from "lib/hdp-solidity/src/datatypes/module/ModuleCodecs.sol";
import {IFactsRegistry} from "lib/hdp-solidity/src/interfaces/IFactsRegistry.sol";
import {IAggregatorsFactory} from "lib/hdp-solidity/src/interfaces/IAggregatorsFactory.sol";

interface IHdpExecutionStore {
    enum TaskStatus {
        NONE,
        SCHEDULED,
        FINALIZED
    }

    struct TaskResult {
        TaskStatus status;
        bytes32 result;
    }

    event MmrRootCached(uint256 mmrId, uint256 mmrSize, bytes32 mmrRoot);
    
    event ModuleTaskScheduled(ModuleTask moduleTask);

    function PROGRAM_HASH() external view returns (bytes32);

    function SHARP_FACTS_REGISTRY() external view returns (IFactsRegistry);

    function CHAIN_ID() external view returns (uint256);

    function AGGREGATORS_FACTORY() external view returns (IAggregatorsFactory);

    function cachedTasksResult(
        bytes32
    ) external view returns (TaskResult memory);

    function cachedMMRsRoots(
        uint256,
        uint256,
        uint256
    ) external view returns (bytes32);

    function cacheMmrRoot(uint256 mmrId) external;

    function requestExecutionOfModuleTask(
        ModuleTask calldata moduleTask
    ) external;

    function authenticateTaskExecution(
        uint256[] calldata mmrIds,
        uint256[] calldata mmrSizes,
        uint256 taskMerkleRootLow,
        uint256 taskMerkleRootHigh,
        uint256 resultMerkleRootLow,
        uint256 resultMerkleRootHigh,
        bytes32[][] memory tasksInclusionProofs,
        bytes32[][] memory resultsInclusionProofs,
        bytes32[] calldata taskCommitments,
        bytes32[] calldata taskResults
    ) external;

    function loadMmrRoot(
        uint256 mmrId,
        uint256 mmrSize
    ) external view returns (bytes32);

    function getFinalizedTaskResult(
        bytes32 taskCommitment
    ) external view returns (bytes32);

    function getTaskStatus(
        bytes32 taskCommitment
    ) external view returns (TaskStatus);

    function standardLeafHash(bytes32 value) external pure returns (bytes32);
}
