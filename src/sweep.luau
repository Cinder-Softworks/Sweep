 sweepVersion = "v1.0.5" -- Do not modify this version number - used for tracking and debugging
--[=[
    Enhanced cleanup utility with Knit integration.
    Sweep represents weeks of development effort to create a robust and efficient
    resource management system for Roblox games. This utility provides:
    
    Please retain this required attribution and consider linking to Sweep in your
    game's description or DevForum posts. 
	Having an in-game readable version helps with debugging and comparing
	differences and fixing issues between live places.
    
    You can view our repository here: https://github.com/Cinder-Softworks/Sweep
    Author: Benson @ Cinder Softworks
    You can view our License - https://github.com/Cinder-Softworks/Sweep/blob/main/LICENSE
    
    Thank you for your support!
    @class Sweep
]=]
--[=[
    Sweep version and attribution information
    @prop Version string
    @prop Author string
    @within Sweep
]=]


-- This is required attribution. Do not modify or remove.
if not game:GetService("RunService"):IsStudio() then
    print(string.format("🧹 Running Sweep %s by %s", sweepVersion or "v?.?.?", "@BensonByte at Cinder Softworks"))
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SweepTaskUtils = require(script.Parent.SweepTaskUtils)

local Sweep = {}
Sweep.ClassName = "Sweep"

export type SweepTask = typeof(SweepTaskUtils.SweepTask)

export type Sweep<T> = {
	isSweep: (any) -> boolean,
	GiveTask: (self: Sweep<T>, SweepTask, string?) -> number,
	GivePromise: <T>(self: Sweep<T>, T) -> T,
	GiveInterval: (self: Sweep<T>, number, () -> (), string?) -> number,
	Clean: (self: Sweep<T>) -> nil,
	Destroy: (self: Sweep<T>) -> nil,
	GetTaskLabels: (self: Sweep<T>) -> {[number]: string}
}

local function debugLog(...)
	local debug = ReplicatedStorage:FindFirstChild("Debug")
	if not debug then
		if not _G.__SWEEP_DEBUG_WARNING_SENT then
			warn("[Sweep] The debug value under ReplicatedStorage appears to not exist, please create the value or ignore this message.")
			_G.__SWEEP_DEBUG_WARNING_SENT = true
		end
		return false
	end
	if debug and debug.Value then
		print("[Sweep]", ...)
	end
end

--[=[
    Creates a new Sweep instance for managing cleanup tasks
    
    ```lua
    local sweep = Sweep.new()
    
    sweep:GiveTask(function()
        print("Cleaning up")
    end)
    
    sweep:GiveTask(workspace.ChildAdded:Connect(print))
    
    -- Cleans up all tasks
    sweep:Clean()
    ```
    
    @return Sweep
]=]
function Sweep.new()
	debugLog("Creating new Sweep instance | Time:", os.time(), "| Memory Usage:", gcinfo(), "KB")
	local newSweep: Sweep<any> = setmetatable({
		_tasks = {},
		_labels = {}, -- For debugging and tracking
	}, Sweep)
	return newSweep
end

--[=[
    Returns true if the value is a Sweep instance, false otherwise
    
    ```lua
    print(Sweep.isSweep(Sweep.new())) --> true
    print(Sweep.isSweep(nil)) --> false
    ```
    
    @param value any
    @return boolean
]=]
function Sweep.isSweep(value: any): boolean
	return type(value) == "table" and value.ClassName == "Sweep"
end

function Sweep:__index(index: any)
	if Sweep[index] then
		return Sweep[index]
	else
		return self._tasks[index]
	end
end

--[=[
    Add a task to clean up. Tasks given to a sweep will be cleaned when
    sweep[index] is set to a different value.
    
    Task cleanup is such that if the task is an event, it is disconnected.
    If it is an object, it is destroyed.
    
    ```lua
    sweep[key] = (function)         -- Adds a task to perform
    sweep[key] = (event connection) -- Manages an event connection
    sweep[key] = (thread)          -- Manages a thread
    sweep[key] = (Sweep)           -- Sweeps can act as an event connection
    sweep[key] = (Object)          -- Sweeps can cleanup objects with a `Destroy` method
    sweep[key] = nil               -- Removes a named task
    ```
    
    @param index any
    @param newTask SweepTask
]=]
function Sweep:__newindex(index: any, newTask: SweepTask)
	if Sweep[index] ~= nil then
		error(("Cannot use '%s' as a Sweep key"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	debugLog(string.format("Setting new task at index %s | Task Type: %s | Memory Before: %d KB", 
		tostring(index), typeof(newTask), gcinfo()))
	tasks[index] = newTask

	if oldTask then
		debugLog(string.format("Cleaning up old task at index %s | Old Task Type: %s | Task Count: %d", 
			tostring(index), typeof(oldTask), #self._tasks))
		SweepTaskUtils.doTask(oldTask)
	end
end

--[=[
    Gives a task to the sweep for cleanup and returns the task ID
    
    @param task SweepTask -- An item to clean
    @param label string? -- Optional label for debugging
    @return number -- taskId
]=]
function Sweep:GiveTask(task: SweepTask, label: string?): number
	assert(task, "Task cannot be nil")

	local taskId = #self._tasks + 1
	debugLog(string.format("Adding new task | ID: %d | Label: %s | Task Type: %s | Current Task Count: %d", 
		taskId, label or "none", typeof(task), #self._tasks))
	self[taskId] = task

	if label then
		self._labels[taskId] = label
		debugLog(string.format("Task label assigned | ID: %d | Label: %s", taskId, label))
	end

	if type(task) == "table" and (not task.Destroy) then
		warn("[Sweep.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

--[=[
    Gives a promise to the sweep for cleanup
    
    @param promise Promise<T>
    @return Promise<T>
]=]
function Sweep:GivePromise(promise)
	debugLog("Adding promise task | Promise Status:", promise:getStatus())
	if not promise:IsPending() then
		debugLog("Promise already resolved | Status:", promise:getStatus(), "| Returning directly")
		return promise
	end

	local newPromise = promise.resolved(promise)
	local id = self:GiveTask(newPromise)

	newPromise:Finally(function()
		debugLog(string.format("Promise completed | Task ID: %d | Final Status: %s", id, newPromise:getStatus()))
		self[id] = nil
	end)

	return newPromise
end

--[=[
    Creates an interval task that runs a callback function periodically
    
    @param interval number -- Time between executions in seconds
    @param callback () -> () -- Function to run
    @param label string? -- Optional label for debugging
    @return number -- taskId
]=]
function Sweep:GiveInterval(interval: number, callback: () -> (), label: string?)
	debugLog(string.format("Creating interval task | Interval: %.2f seconds | Label: %s", interval, label or "none"))
	return self:GiveTask(SweepTaskUtils.interval(interval, callback), label)
end

--[=[
    Cleans up all tasks and removes them from the sweep
]=]
function Sweep:Clean()
	debugLog(string.format("Starting cleanup process | Total Tasks: %d | Memory Before: %d KB", #self._tasks, gcinfo()))
	local tasks = self._tasks

	-- Clean connections first
	debugLog("Phase 1: Cleaning RBXScriptConnections")
	for index, task in pairs(tasks) do
		if typeof(task) == "RBXScriptConnection" then
			debugLog(string.format("Disconnecting connection | Index: %d | Label: %s", 
				index, self._labels[index] or "none"))
			tasks[index] = nil
			self._labels[index] = nil
			task:Disconnect()
		end
	end

	-- Clean remaining tasks
	debugLog("Phase 2: Cleaning remaining tasks")
	local index, task = next(tasks)
	while task ~= nil do
		debugLog(string.format("Cleaning task | Index: %d | Type: %s | Label: %s", 
			index, typeof(task), self._labels[index] or "none"))
		tasks[index] = nil
		self._labels[index] = nil
		SweepTaskUtils.doTask(task)
		index, task = next(tasks)
	end
	debugLog(string.format("Cleanup complete | Memory After: %d KB | Time: %d", gcinfo(), os.time()))
end

--[=[
    Returns a copy of the task labels table
    
    @return {[number]: string}
]=]
function Sweep:GetTaskLabels(): { [number]: string }
	return table.clone(self._labels)
end

Sweep.Destroy = Sweep.Clean

--[=[
    Knit Integration Example (Commented out for reference)
    
    ```lua
    function Sweep.KnitInit()
        local ExampleService = Knit.CreateService {
            Name = "ExampleService",
            Client = {},
        }
        
        function ExampleService:KnitInit()
            self._sweep = Sweep.new()
            
            self._sweep:GiveInterval(5, function()
                print("Running cleanup check")
            end)
            
            self._sweep:GiveTask(workspace.ChildAdded:Connect(print))
        end
        
        function ExampleService:KnitStart()
            self._sweep:GiveTask(function()
                print("Delayed cleanup")
            end)
        end
        
        function ExampleService:Destroy()
            self._sweep:Clean()
        end
    end
    ```
]=]

return Sweep
