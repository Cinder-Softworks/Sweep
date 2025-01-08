--[=[
    Utility methods for Sweep tasks management. 
    @class SweepTaskUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SweepTaskUtils = {}

local function debugLog(...)
    local debug = ReplicatedStorage:FindFirstChild("Debug")
    if not debug then return false end
    if debug and debug.Value then
        print("[SweepTaskUtils Debug]", ...)
    end
end

--[=[
    An object that can have the method :Destroy() called on it
    @type Destructable Instance | { Destroy: () -> () }
    @within SweepTaskUtils
]=]
export type Destructable = Instance | { Destroy: () -> () }

--[=[
    An object that can be cleaned up
    @type SweepTask function | Destructable | RBXScriptConnection | thread
    @within SweepTaskUtils
]=]
export type SweepTask = (() -> ()) | Destructable | RBXScriptConnection | thread

--[=[
    Validates if a task is a valid cleanup task
    
    ```lua
    print(SweepTaskUtils.isValidTask(function() end)) --> true
    print(SweepTaskUtils.isValidTask(workspace.ChildAdded:Connect(function() end))) --> true
    print(SweepTaskUtils.isValidTask(nil)) --> false
    ```
    
    @param task any -- Task to validate
    @return boolean -- Whether the task is valid
]=]
function SweepTaskUtils.isValidTask(task: any): boolean
    debugLog(string.format("Validating task | Type: %s | Memory Usage: %d KB", type(task), gcinfo()))
    return type(task) == "function"
        or typeof(task) == "RBXScriptConnection"
        or type(task) == "table" and type(task.Destroy) == "function"
        or typeof(task) == "Instance"
        or type(task) == "thread"
end

--[=[
    Executes a cleanup task based on its type
    
    ```lua
    -- Clean up a function
    SweepTaskUtils.doTask(function() print("Cleaned!") end)
    
    -- Clean up a connection
    local connection = workspace.ChildAdded:Connect(print)
    SweepTaskUtils.doTask(connection)
    
    -- Clean up an object with Destroy method
    local part = Instance.new("Part")
    SweepTaskUtils.doTask(part)
    ```
    
    @param task SweepTask -- Task to execute
]=]
function SweepTaskUtils.doTask(task: SweepTask)
    debugLog(string.format("Executing task | Type: %s | Memory Before: %d KB", type(task), gcinfo()))
    
    -- Handle connections first as recommended in technical docs
    if typeof(task) == "RBXScriptConnection" then
        debugLog("Disconnecting RBXScriptConnection | Connection Status: Active")
        task:Disconnect()
        debugLog("RBXScriptConnection disconnected successfully")
        return
    end
    
    -- Handle other task types
    if type(task) == "function" then
        debugLog("Executing function task | Stack Trace:", debug.traceback())
        task()
    elseif type(task) == "table" and type(task.Destroy) == "function" then
        debugLog(string.format("Destroying table with Destroy method | Table Info: %s", tostring(task)))
        task:Destroy()
    elseif typeof(task) == "Instance" then
        debugLog(string.format("Destroying Instance | Name: %s | ClassName: %s | Parent: %s", 
            task.Name, task.ClassName, task.Parent and task.Parent.Name or "nil"))
        task:Destroy()
    elseif type(task) == "thread" then
        debugLog(string.format("Canceling thread | Thread Status: %s", coroutine.status(task)))
        task.cancel(task)
    else
        debugLog(string.format("ERROR: Invalid task type | Type: %s | Value: %s", type(task), tostring(task)))
        error("Invalid task type")
    end
    
    debugLog(string.format("Task execution completed | Memory After: %d KB", gcinfo()))
end

--[=[
    Creates a delayed task that executes after a specified time
    
    ```lua
    -- Delays cleanup by 5 seconds
    sweep:GiveTask(SweepTaskUtils.delayed(5, function()
        print("Cleaned after 5 seconds!")
    end))
    ```
    
    @param time number -- Time in seconds to delay
    @param task SweepTask -- Task to execute after delay
    @return () -> () -- Function that will execute the delayed task
]=]
function SweepTaskUtils.delayed(time: number, task: SweepTask): () -> ()
    debugLog(string.format("Creating delayed task | Delay: %.2f seconds | Task Type: %s | Memory: %d KB", 
        time, type(task), gcinfo()))
    assert(type(time) == "number", "Time must be a number")
    assert(SweepTaskUtils.isValidTask(task), "Invalid task")

    return function()
        debugLog(string.format("Starting delayed task execution | Time: %.2f | Current Time: %d", time, os.time()))
        local thread = task.delay(time, function()
            debugLog(string.format("Executing delayed task | Time Elapsed: %.2f seconds | Memory Before: %d KB", 
                time, gcinfo()))
            SweepTaskUtils.doTask(task)
            debugLog(string.format("Delayed task completed | Memory After: %d KB", gcinfo()))
        end)
        return function()
            task.cancel(thread)
        end
    end
end

--[=[
    Creates an interval task that runs a callback function periodically
    
    ```lua
    -- Runs every 5 seconds
    sweep:GiveTask(SweepTaskUtils.interval(5, function()
        print("Running every 5 seconds!")
    end))
    ```
    
    @param interval number -- Time between executions in seconds
    @param callback () -> () -- Function to run at each interval
    @return () -> () -- Function that stops the interval when called
]=]
function SweepTaskUtils.interval(interval: number, callback: () -> ()): () -> ()
    debugLog(string.format("Creating interval task | Interval: %.2f seconds | Memory Before: %d KB", 
        interval, gcinfo()))
    assert(type(interval) == "number", "Interval must be a number")
    assert(type(callback) == "function", "Callback must be a function")

    local running = true
    local thread = task.spawn(function()
        debugLog("Starting interval loop | Initial Time:", os.time())
        while running do
            local success, err = pcall(callback)
            if not success then
                debugLog("Error in interval callback:", err)
                break
            end
            if not running then break end
            task.wait(interval)
        end
    end)

    return function()
        debugLog(string.format("Stopping interval task | Final Time: %d | Memory Before: %d KB", 
            os.time(), gcinfo()))
        running = false
        task.cancel(thread)
        debugLog(string.format("Interval task stopped | Memory After: %d KB", gcinfo()))
    end
end

return SweepTaskUtils
