# Technical Reference

## Type Definitions

### SweepTask
```lua
type SweepTask = (() -> ()) | Destructable | RBXScriptConnection | thread
```

A SweepTask can be any of the following:
- A function that can be called for cleanup
- A Destructable object (Instance or object with Destroy method)
- A [RBXScriptConnection](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptConnection)
- A [thread](https://create.roblox.com/docs/reference/engine/libraries/coroutine) (coroutine)

### Destructable
```lua
type Destructable = Instance | { Destroy: () -> () }
```

A Destructable is either:
- A [Roblox Instance](https://create.roblox.com/docs/reference/engine/classes/Instance)
- Any object with a Destroy method

## Internal Implementation Details

### Task Storage
Tasks are stored internally in the Sweep instance using two main tables:
```lua
self._tasks = {} -- Stores the actual tasks
self._labels = {} -- Stores optional debug labels for tasks
```

### Task Indexing
- Tasks are indexed numerically starting from 1
- Each task gets a unique ID returned by `GiveTask`
- Labels are stored with the same index as their corresponding task

### Memory Management

#### Garbage Collection
- Tasks are properly dereferenced when cleaned
- Connections are explicitly disconnected
- Objects are destroyed using their Destroy method
- Threads are cancelled using task_cancel

#### Connection Handling
Connections are prioritized during cleanup:
```lua
-- Clean connections first to prevent any pending events
for index, task in pairs(tasks) do
    if typeof(task) == "RBXScriptConnection" then
        task:Disconnect()
        tasks[index] = nil
        self._labels[index] = nil
    end
end
```

### Debug System

#### Debug Mode
Debug mode is controlled by a Value instance in ReplicatedStorage:
```lua
local debug = ReplicatedStorage:FindFirstChild("Debug")
if debug and debug.Value then
    print("[Sweep Debug]", ...)
end
```

#### Debug Information
When debug mode is enabled, the following information is logged:
- Task creation and deletion
- Memory usage (via gcinfo())
- Stack traces for important operations
- Task type information
- Connection states
- Thread states

### Debug Logging
The debug system provides detailed logging for:
- Task creation and cleanup
- Memory usage tracking
- Task execution timing
- Connection states
- Thread management
- Promise resolution

Debug messages include timestamps and memory usage metrics to help with performance monitoring.

## Advanced Usage

### Custom Task Types

You can extend Sweep to handle custom task types by modifying the isValidTask and doTask functions:

```lua
-- Example of adding custom task type
local CustomTask = {}
CustomTask.__index = CustomTask

function CustomTask.new()
    return setmetatable({
        _cleanup = function() end
    }, CustomTask)
end

function CustomTask:Destroy()
    self._cleanup()
end

-- Usage with Sweep
local customTask = CustomTask.new()
sweep:GiveTask(customTask)
```

### Promise Integration Details

The Promise integration handles different promise states:

```lua
function Sweep:GivePromise(promise)
    -- Return immediately if promise is already resolved
    if not promise:IsPending() then
        return promise
    end

    -- Create new promise that can be tracked
    local newPromise = promise.resolved(promise)
    local id = self:GiveTask(newPromise)

    -- Clean up automatically when promise completes
    newPromise:Finally(function()
        self[id] = nil
    end)

    return newPromise
end
```

### Interval Task Implementation

Interval tasks are implemented using a combination of task.spawn and task.wait:

```lua
function SweepTaskUtils.interval(interval, callback)
    local running = true
    local thread = task.spawn(function()
        while running do
            callback()
            task.wait(interval)
        end
    end)

    return function()
        running = false
        task.cancel(thread)
    end
end
```

## Performance Considerations

### Memory Usage
- Each task requires minimal overhead (just table entries)
- Labels add additional memory overhead per task
- Debug mode increases memory usage due to logging

### CPU Usage
- Task cleanup is performed sequentially
- Connections are prioritized in cleanup
- Interval tasks run on separate threads
- Promise resolution is asynchronous

### Best Practices for Performance

1. **Task Creation**
   ```lua
   -- Preferred: Single task for multiple operations
   sweep:GiveTask(function()
       cleanup1()
       cleanup2()
       cleanup3()
   end)

   -- Avoid: Multiple individual tasks
   sweep:GiveTask(cleanup1)
   sweep:GiveTask(cleanup2)
   sweep:GiveTask(cleanup3)
   ```

2. **Connection Management**
   ```lua
   -- Preferred: Group related connections
   sweep:GiveTask(function()
       local conn1 = obj.Event1:Connect(handler1)
       local conn2 = obj.Event2:Connect(handler2)
       return function()
           conn1:Disconnect()
           conn2:Disconnect()
       end
   end)
   ```

3. **Memory Optimization**
   ```lua
   -- Preferred: Clean unused tasks immediately
   local taskId = sweep:GiveTask(heavyOperation)
   -- ... use the operation ...
   sweep[taskId] = nil  -- Clean up when done

   -- Avoid: Keeping unnecessary tasks
   sweep:GiveTask(heavyOperation)  -- Tasks stays until sweep:Clean()
   ```

## Integration Patterns

### Service Pattern
```lua
local MyService = Knit.CreateService({
    Name = "MyService",
    Client = {},
    _sweep = nil,
})

function MyService:KnitInit()
    self._sweep = Sweep.new()
    
    -- Lifecycle management
    self._sweep:GiveTask(function()
        self:SetupService()
        return function()
            self:TeardownService()
        end
    end)
    
    -- Event management
    self._sweep:GiveTask(game.Players.PlayerAdded:Connect(function(player)
        self:HandleNewPlayer(player)
    end))
end

function MyService:KnitStart()
    -- Start operations
    self._sweep:GiveInterval(1, function()
        self:Update()
    end)
end

function MyService:Destroy()
    self._sweep:Clean()
end
```

### Controller Pattern
```lua
local MyController = Knit.CreateController({
    Name = "MyController",
    _sweep = nil,
})

function MyController:KnitInit()
    self._sweep = Sweep.new()
    
    -- UI Management
    self._sweep:GiveTask(function()
        local ui = self:SetupUI()
        return function()
            ui:Destroy()
        end
    end)
end

function MyController:KnitStart()
    -- Handle UI Events
    self._sweep:GiveTask(self.ui.Button.Activated:Connect(function()
        self:HandleButtonClick()
    end))
end
```

### Component Pattern
```lua
local MyComponent = {}
MyComponent.__index = MyComponent

function MyComponent.new(instance)
    local self = setmetatable({}, MyComponent)
    self._sweep = Sweep.new()
    self._instance = instance
    
    self:Init()
    return self
end

function MyComponent:Init()
    -- Instance cleanup
    self._sweep:GiveTask(self._instance)
    
    -- Attribute handling
    self._sweep:GiveTask(self._instance:GetAttributeChangedSignal("State"):Connect(function()
        self:HandleStateChange()
    end))
end

function MyComponent:Destroy()
    self._sweep:Clean()
end
```

### Task Labels
```lua
function Sweep:GetTaskLabels(): {[number]: string}
    -- Returns a copy of all task labels
    return table.clone(self._labels)
end
``` 

