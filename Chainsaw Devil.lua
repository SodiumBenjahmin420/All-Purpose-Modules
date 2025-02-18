-- Chainsaw Devil Module
-- A globally accessible, functional cleanup management system for Roblox executions

local HttpService = game:GetService("HttpService")

-- Initialize global state in the environment
local env = getgenv()
if not env.ChainSawDevilCache then
    env.ChainSawDevilCache = {
        Executions = {}, -- Stores all Chainsaw Devil instances
        ActiveExecutionId = nil -- Tracks the currently active execution
    }
end

-- Type definitions for better code understanding
export type ConsumableType = "connection" | "instance" | "signal" | "unknown"
export type Consumable = {
    item: any,
    type: ConsumableType
}

export type Execution = {
    Id: string,
    Name: string,
    Consumables: {[any]: Consumable},  -- Using table lookup instead of array
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
    
    return self
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

-- Consumes (tracks) a new item for later cleanup
-- Returns the connection/instance/signal for chainable operations
function ChainsawDevil:Eat(item: any, callback: (...any) -> any): any
    assert(self.Active, "Cannot eat new items with an inactive Chainsaw Devil")
    
    local consumableType = getConsumableType(item)
    assert(consumableType ~= "unknown", "Cannot consume unknown item type")
    
    local result
    
    -- Handle different types of consumables
    if consumableType == "connection" then
        result = item
    elseif consumableType == "instance" then
        result = item
    elseif callback and consumableType ~= "signal" then
        result = item:Connect(callback)
        consumableType = "connection"
    else
        result = item
    end
    
    -- Store the consumable with direct table lookup
    self.Consumables[result] = {
        item = result,
        type = consumableType
    }
    
    return result
end

-- Cleans up a specific item using direct table lookup
function ChainsawDevil:Digest(item: any)
    assert(self.Active, "Cannot digest items with an inactive Chainsaw Devil")
    
    local consumable = self.Consumables[item]
    if consumable then
        if consumable.type == "connection" and consumable.item.Connected then
            consumable.item:Disconnect()
        elseif (consumable.type == "instance" or consumable.type == "signal") and not consumable.item.Destroying then
            consumable.item:Destroy()
        end
        self.Consumables[item] = nil
    end
end

-- Cleans up everything tracked by this Chainsaw Devil instance
function ChainsawDevil:Cleanup()
    if not self.Active then return end
    
    -- Clean up all consumables
    for _, consumable in pairs(self.Consumables) do
        if consumable.type == "connection" and consumable.item.Connected then
            consumable.item:Disconnect()
        elseif (consumable.type == "instance" or consumable.type == "signal") and not consumable.item.Destroying then
            consumable.item:Destroy()
        end
    end
    
    -- Clear the consumables table
    table.clear(self.Consumables)
    self.Active = false
    
    -- Remove from global cache
    env.ChainSawDevilCache.Executions[self.ExecutionId] = nil
    if env.ChainSawDevilCache.ActiveExecutionId == self.ExecutionId then
        env.ChainSawDevilCache.ActiveExecutionId = nil
    end
end

-- Clean up all executions
function ChainsawDevil.CleanupAll()
    for _, execution in pairs(env.ChainSawDevilCache.Executions) do
        execution:Cleanup()
    end
    table.clear(env.ChainSawDevilCache.Executions)
    env.ChainSawDevilCache.ActiveExecutionId = nil
end

return ChainsawDevil
