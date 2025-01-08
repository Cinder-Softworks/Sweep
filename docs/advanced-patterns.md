# Advanced Patterns and Use Cases

## Table of Contents
- [Advanced Task Management](#advanced-task-management)
- [Complex Integration Patterns](#complex-integration-patterns)
- [Error Handling](#error-handling)
- [Testing Patterns](#testing-patterns)
- [Common Pitfalls](#common-pitfalls)

## Advanced Task Management

### Nested Tasks
Tasks can be nested to create complex cleanup hierarchies:

```lua
local sweep = Sweep.new()

-- Parent task that manages child tasks
sweep:GiveTask(function()
    local childSweep = Sweep.new()
    
    -- Add child tasks
    childSweep:GiveTask(workspace.ChildAdded:Connect(print))
    childSweep:GiveTask(workspace.ChildRemoved:Connect(print))
    
    -- Return cleanup function that cleans child tasks
    return function()
        childSweep:Clean()
    end
end)
```

### Conditional Tasks
Tasks that only need to be cleaned up under certain conditions:

```lua
local function createConditionalTask(condition)
    local sweep = Sweep.new()
    
    sweep:GiveTask(function()
        if condition() then
            -- Setup that only runs if condition is met
            local connection = workspace.ChildAdded:Connect(print)
            return function()
                connection:Disconnect()
            end
        end
    end)
    
    return sweep
end
```

### Task Groups
Organizing related tasks together:

```lua
local function createTaskGroup(sweep, groupName)
    local tasks = {}
    
    local function addTask(task)
        local id = sweep:GiveTask(task, groupName .. "_" .. #tasks + 1)
        table.insert(tasks, id)
        return id
    end
    
    local function cleanGroup()
        for _, id in ipairs(tasks) do
            sweep[id] = nil
        end
        table.clear(tasks)
    end
    
    return {
        addTask = addTask,
        cleanGroup = cleanGroup
    }
end

-- Usage
local sweep = Sweep.new()
local uiTasks = createTaskGroup(sweep, "UI")

uiTasks.addTask(function()
    -- UI setup
end)

-- Clean only UI tasks
uiTasks.cleanGroup()
```

## Complex Integration Patterns

### State Management
Managing state with cleanup:

```lua
local StateManager = {}
StateManager.__index = StateManager

function StateManager.new()
    local self = setmetatable({}, StateManager)
    self._sweep = Sweep.new()
    self._state = {}
    self._listeners = {}
    
    return self
end

function StateManager:setState(key, value)
    self._state[key] = value
    
    -- Clean up old listeners
    if self._listeners[key] then
        self._sweep[self._listeners[key]] = nil
    end
    
    -- Setup new state listeners
    self._listeners[key] = self._sweep:GiveTask(function()
        self:_handleStateChange(key, value)
        return function()
            self:_cleanupState(key)
        end
    end)
end

function StateManager:Destroy()
    self._sweep:Clean()
end
```

### Resource Pooling
Managing pools of resources:

```lua
local ResourcePool = {}
ResourcePool.__index = ResourcePool

function ResourcePool.new(createResource)
    local self = setmetatable({}, ResourcePool)
    self._sweep = Sweep.new()
    self._pool = {}
    self._createResource = createResource
    
    -- Cleanup all resources when pool is destroyed
    self._sweep:GiveTask(function()
        return function()
            for _, resource in ipairs(self._pool) do
                resource:Destroy()
            end
        end
    end)
    
    return self
end

function ResourcePool:acquire()
    local resource = table.remove(self._pool) or self._createResource()
    
    -- Track active resources
    self._sweep:GiveTask(function()
        return function()
            table.insert(self._pool, resource)
        end
    end)
    
    return resource
end
```

### Event Aggregation
Combining multiple events:

```lua
local function createEventAggregator(events)
    local sweep = Sweep.new()
    local signal = Instance.new("BindableEvent")
    
    -- Connect all events
    for name, event in pairs(events) do
        sweep:GiveTask(event:Connect(function(...)
            signal:Fire(name, ...)
        end))
    end
    
    -- Clean up signal on destroy
    sweep:GiveTask(signal)
    
    return signal.Event
end

-- Usage
local events = {
    playerJoined = game.Players.PlayerAdded,
    playerLeft = game.Players.PlayerRemoved
}

local aggregatedEvent = createEventAggregator(events)
```

## Error Handling

### Task Error Recovery
Handling errors in tasks:

```lua
function SafeTask(task)
    return function()
        local success, result = pcall(task)
        if not success then
            warn("Task failed:", result)
            -- Implement recovery logic here
        end
    end
end

-- Usage
sweep:GiveTask(SafeTask(function()
    error("Something went wrong")
end))
```

### Cleanup Error Handling
Ensuring cleanup happens even if errors occur:

```lua
function SafeCleanup(sweep)
    return function()
        local success, err = pcall(function()
            sweep:Clean()
        end)
        
        if not success then
            warn("Cleanup failed:", err)
            -- Emergency cleanup
            for _, task in pairs(sweep._tasks) do
                pcall(function()
                    if typeof(task) == "RBXScriptConnection" then
                        task:Disconnect()
                    elseif type(task) == "function" then
                        task()
                    end
                end)
            end
        end
    end
end
```

## Testing Patterns

### Mock Tasks
Creating testable tasks:

```lua
local function createMockTask()
    local cleaned = false
    
    return {
        task = function()
            return function()
                cleaned = true
            end
        end,
        
        wasCleaned = function()
            return cleaned
        end
    }
end

-- Test usage
local mockTask = createMockTask()
local sweep = Sweep.new()

sweep:GiveTask(mockTask.task())
sweep:Clean()

assert(mockTask.wasCleaned(), "Task was not cleaned up")
```

### Task Tracking
Tracking task lifecycle for testing:

```lua
local function createTrackingDecorator(sweep)
    local tracking = {
        created = {},
        cleaned = {}
    }
    
    local originalGiveTask = sweep.GiveTask
    sweep.GiveTask = function(self, task, label)
        local id = originalGiveTask(self, task, label)
        tracking.created[id] = {
            task = task,
            label = label,
            time = os.clock()
        }
        return id
    end
    
    local originalClean = sweep.Clean
    sweep.Clean = function(self)
        for id, info in pairs(tracking.created) do
            if not tracking.cleaned[id] then
                tracking.cleaned[id] = {
                    time = os.clock(),
                    lifetime = os.clock() - info.time
                }
            end
        end
        originalClean(self)
    end
    
    return tracking
end
```

## Common Pitfalls

### Memory Leaks
Common causes and solutions:

```lua
-- BAD: Circular reference
local function createCircularReference()
    local sweep = Sweep.new()
    local obj = {}
    
    sweep:GiveTask(function()
        obj.ref = sweep  -- Creates circular reference
    end)
    
    return obj
end

-- GOOD: Avoid circular references
local function createSafeReference()
    local sweep = Sweep.new()
    local obj = {}
    
    sweep:GiveTask(function()
        obj.cleanup = function()
            sweep:Clean()
        end
    end)
    
    return obj
end
```

### Task Dependencies
Managing tasks with dependencies:

```lua
local function createDependentTasks(sweep)
    -- Track task dependencies
    local dependencies = {}
    
    local function addTaskWithDependencies(task, deps)
        -- Ensure all dependencies exist
        for _, dep in ipairs(deps) do
            if not sweep._tasks[dep] then
                error("Dependency " .. dep .. " does not exist")
            end
        end
        
        -- Add task
        local id = sweep:GiveTask(task)
        dependencies[id] = deps
        
        return id
    end
    
    -- Override clean to respect dependencies
    local originalClean = sweep.Clean
    sweep.Clean = function(self)
        -- Sort tasks by dependencies
        local sorted = {}
        local visited = {}
        
        local function visit(id)
            if visited[id] then return end
            visited[id] = true
            
            for _, dep in ipairs(dependencies[id] or {}) do
                visit(dep)
            end
            
            table.insert(sorted, id)
        end
        
        for id in pairs(self._tasks) do
            visit(id)
        end
        
        -- Clean in dependency order
        for _, id in ipairs(sorted) do
            if self._tasks[id] then
                SweepTaskUtils.doTask(self._tasks[id])
                self._tasks[id] = nil
            end
        end
    end
    
    return {
        addTaskWithDependencies = addTaskWithDependencies
    }
end
```

### Performance Issues
Avoiding common performance problems:

```lua
-- BAD: Creating many small tasks
for i = 1, 1000 do
    sweep:GiveTask(function()
        print("Cleanup", i)
    end)
end

-- GOOD: Batch tasks together
sweep:GiveTask(function()
    local cleanups = {}
    for i = 1, 1000 do
        table.insert(cleanups, function()
            print("Cleanup", i)
        end)
    end
    return function()
        for _, cleanup in ipairs(cleanups) do
            cleanup()
        end
    end
end)
``` 
