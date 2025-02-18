-- Chainsaw Devil Module
-- A globally accessible, functional cleanup management system for Roblox executions

local HttpService = game:GetService("HttpService")

-- Debug logging function to maintain consistent format
local function debugLog(category, message, details)
    local timestamp = os.date("%H:%M:%S")
    local detailsStr = details and (" | " .. tostring(details)) or ""
    print(string.format("[Chainsaw Devil %s] %s - %s%s", timestamp, category, message, detailsStr))
end

-- Initialize global state in the environment
local env = getgenv()
if not env.ChainSawDevilCache then
    debugLog("Init", "Creating new global cache")
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
    
    debugLog("Creation", string.format("New execution created: %s", self.Name), {
        id = executionId,
        active = true
    })
    
    -- Store the execution in global cache
    env.ChainSawDevilCache.Executions[executionId] = self
    env.ChainSawDevilCache.ActiveExecutionId = executionId
    
    return self
end

-- Get the currently active execution
function ChainsawDevil.GetActive(): Execution?
    local activeId = env.ChainSawDevilCache.ActiveExecutionId
    local active = activeId and env.ChainSawDevilCache.Executions[activeId]
    debugLog("Access", "Getting active execution", {
        id = activeId,
        name = active and active.Name or "None"
    })
    return active
end

-- Switch the active execution
function ChainsawDevil.SetActive(executionId: string)
    assert(env.ChainSawDevilCache.Executions[executionId], "Execution does not exist")
    local prevId = env.ChainSawDevilCache.ActiveExecutionId
    env.ChainSawDevilCache.ActiveExecutionId = executionId
    
    debugLog("Switch", "Active execution changed", {
        from = prevId,
        to = executionId,
        name = env.ChainSawDevilCache.Executions[executionId].Name
    })
end

-- Consumes (tracks) a new item for later cleanup
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
    
    debugLog("Consume", string.format("Item consumed by %s", self.Name), {
        type = consumableType,
        itemType = typeof(result),
        totalConsumables = #(self.Consumables)
    })
    
    return result
end

-- Cleans up a specific item using direct table lookup
function ChainsawDevil:Digest(item: any)
    assert(self.Active, "Cannot digest items with an inactive Chainsaw Devil")
    
    local consumable = self.Consumables[item]
    if consumable then
        if consumable.type == "connection" and consumable.item.Connected then
            consumable.item:Disconnect()
            debugLog("Cleanup", "Connection disconnected", {
                execution = self.Name
            })
        elseif (consumable.type == "instance" or consumable.type == "signal") and not consumable.item.Destroying then
            consumable.item:Destroy()
            debugLog("Cleanup", string.format("%s destroyed", consumable.type), {
                execution = self.Name
            })
        end
        self.Consumables[item] = nil
        
        debugLog("Digest", "Item removed from tracking", {
            execution = self.Name,
            remainingConsumables = #table.keys(self.Consumables)
        })
    end
end

-- Cleans up everything tracked by this Chainsaw Devil instance
function ChainsawDevil:Cleanup()
    if not self.Active then 
        debugLog("Cleanup", "Attempted cleanup on inactive execution", {
            name = self.Name,
            id = self.ExecutionId
        })
        return 
    end
    
    debugLog("Cleanup", string.format("Starting cleanup for %s", self.Name), {
        id = self.ExecutionId,
        consumablesCount = #table.keys(self.Consumables)
    })
    
    -- Clean up all consumables
    for _, consumable in pairs(self.Consumables) do
        if consumable.type == "connection" and consumable.item.Connected then
            consumable.item:Disconnect()
            debugLog("Cleanup", "Connection disconnected", {
                execution = self.Name
            })
        elseif (consumable.type == "instance" or consumable.type == "signal") and not consumable.item.Destroying then
            consumable.item:Destroy()
            debugLog("Cleanup", string.format("%s destroyed", consumable.type), {
                execution = self.Name
            })
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
    
    debugLog("Cleanup", string.format("Completed cleanup for %s", self.Name), {
        id = self.ExecutionId
    })
end

function ChainsawDevil.CleanupGlobal(Name: string)
    debugLog("Global", string.format("Starting global cleanup for name: %s", Name))
    
    -- Create a temporary table to store executions to clean up
    local executionsToCleanup = {}
    
    -- Gather all executions that match the name
    for id, execution in pairs(env.ChainSawDevilCache.Executions) do
        if execution.Name == Name then
            table.insert(executionsToCleanup, execution)
        end
    end
    
    debugLog("Global", string.format("Found %d executions to clean up", #executionsToCleanup))
    
    -- Clean up all matching executions
    for _, execution in ipairs(executionsToCleanup) do
        execution:Cleanup()
    end
    
    debugLog("Global", string.format("Completed global cleanup for name: %s", Name))
end

-- Clean up all executions
function ChainsawDevil.CleanupAll()
    local executionCount = #table.keys(env.ChainSawDevilCache.Executions)
    debugLog("Global", string.format("Starting cleanup of all executions (%d total)", executionCount))
    
    for _, execution in pairs(env.ChainSawDevilCache.Executions) do
        execution:Cleanup()
    end
    
    table.clear(env.ChainSawDevilCache.Executions)
    env.ChainSawDevilCache.ActiveExecutionId = nil
    
    debugLog("Global", "Completed cleanup of all executions")
end

return ChainsawDevil
