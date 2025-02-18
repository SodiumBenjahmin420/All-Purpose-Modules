-- Chainsaw Devil Module
-- A globally accessible, functional cleanup management system for Roblox executions

local HttpService = game:GetService("HttpService")

-- Initialize global state in the environment
local env = getgenv()
if not env.ChainSawDevilCache then
    env.ChainSawDevilCache = {
        Executions = {}, -- Stores all Chainsaw Devil instances
        ActiveExecutionId = nil, -- Tracks the currently active execution
        LastCreatedId = nil -- Tracks the most recently created execution ID
    }
end

export type ConsumableType = "connection" | "instance" | "signal" | "unknown"
export type Consumable = {
    item: any,
    type: ConsumableType
}

export type Execution = {
    Id: string,
    Name: string,
    Consumables: {[any]: Consumable},
    Active: boolean
}

local ChainsawDevil = {}
ChainsawDevil.__index = ChainsawDevil

-- Utility function to determine the type of consumable
local function getConsumableType(item: any): ConsumableType
    if typeof(item) == "RBXScriptConnection" then
        return "connection"
    elseif typeof(item) == "Instance" then
        return "instance"
    elseif type(item) == "table" and item.Destroy then
        return "signal"
    end
    return "unknown"
end

-- Creates a new Chainsaw Devil instance or retrieves an existing one
function ChainsawDevil.new(ExecutionName: string?)
    local executionId = HttpService:GenerateGUID(false)
    local self = setmetatable({
        ExecutionId = executionId,
        Name = ExecutionName or "Unnamed Execution",
        Consumables = {},
        Active = true
    }, ChainsawDevil)
    
    -- Store the execution in global cache
    env.ChainSawDevilCache.Executions[executionId] = self
    env.ChainSawDevilCache.ActiveExecutionId = executionId
    env.ChainSawDevilCache.LastCreatedId = executionId
    
    return self
end

-- Get the execution ID of the most recently created instance
function ChainsawDevil.GetLastCreatedId(): string?
    return env.ChainSawDevilCache.LastCreatedId
end

-- Get an execution by its ID
function ChainsawDevil.GetExecution(executionId: string): Execution?
    return env.ChainSawDevilCache.Executions[executionId]
end

-- Get the currently active execution
function ChainsawDevil.GetActive(): Execution?
    local activeId = env.ChainSawDevilCache.ActiveExecutionId
    return activeId and env.ChainSawDevilCache.Executions[activeId]
end

-- Switch the active execution
function ChainsawDevil.SetActive(executionId: string)
    assert(env.ChainSawDevilCache.Executions[executionId], "Execution does not exist")
    env.ChainSawDevilCache.ActiveExecutionId = executionId
end

-- Rest of the implementation remains the same...
-- (Eat, Digest, Cleanup, CleanupAll methods stay unchanged)

return ChainsawDevil
