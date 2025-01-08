# Getting Started with Sweep

## Table of Contents
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Common Use Cases](#common-use-cases)
- [Best Practices](#best-practices)
- [Debugging](#debugging)

## Installation

### Requirements
- Roblox Studio
- Knit Framework
- (Optional) ProfileStore for data management

### Setup Steps

1. Add the Sweep framework to your project:
   ```lua
   -- ReplicatedStorage/Packages/Sweep
   local Sweep = require(ReplicatedStorage.Packages.Sweep)
   ```

2. Add SweepTaskUtils:
   ```lua
   -- ReplicatedStorage/Packages/SweepTaskUtils
   local SweepTaskUtils = require(ReplicatedStorage.Packages.SweepTaskUtils)
   ```

3. (Optional) Enable debugging:
   ```lua
   -- Create a BoolValue in ReplicatedStorage named "Debug"
   local debugValue = Instance.new("BoolValue")
   debugValue.Name = "Debug"
   debugValue.Value = true
   debugValue.Parent = game:GetService("ReplicatedStorage")
   ```

## Basic Usage

### Creating a Sweep Instance

```lua
local sweep = Sweep.new()
```

### Adding Tasks

1. Simple Function Task:
   ```lua
   sweep:GiveTask(function()
       print("This will run during cleanup")
   end)
   ```

2. Event Connection:
   ```lua
   sweep:GiveTask(workspace.ChildAdded:Connect(function(child)
       print("New child added:", child.Name)
   end))
   ```

3. Instance Cleanup:
   ```lua
   local part = Instance.new("Part")
   sweep:GiveTask(part)  -- Part will be destroyed during cleanup
   ```

4. Interval Task:
   ```lua
   sweep:GiveInterval(5, function()
       print("Running every 5 seconds")
   end)
   ```

### Cleaning Up

```lua
-- Clean up all tasks
sweep:Clean()

-- Or use Destroy (alias for Clean)
sweep:Destroy()
```

## Common Use Cases

### UI Management

```lua
local function createUI()
    local sweep = Sweep.new()
    local gui = Instance.new("ScreenGui")
    
    -- Cleanup GUI when sweep is cleaned
    sweep:GiveTask(gui)
    
    -- Add button
    local button = Instance.new("TextButton")
    button.Parent = gui
    
    -- Handle button clicks
    sweep:GiveTask(button.Activated:Connect(function()
        print("Button clicked!")
    end))
    
    -- Handle hover effects
    sweep:GiveTask(button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    end))
    
    sweep:GiveTask(button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end))
    
    return gui, sweep
end
```

### Player Management

```lua
local function setupPlayerManager()
    local sweep = Sweep.new()
    local players = {}
    
    -- Handle player joining
    sweep:GiveTask(game.Players.PlayerAdded:Connect(function(player)
        players[player] = true
        
        -- Clean up player-specific tasks when they leave
        sweep:GiveTask(player.AncestryChanged:Connect(function()
            if not player:IsDescendantOf(game) then
                players[player] = nil
            end
        end))
    end))
    
    -- Update all players periodically
    sweep:GiveInterval(1, function()
        for player in pairs(players) do
            -- Do something with player
        end
    end)
    
    return sweep
end
```

### Data Management

```lua
local function createDataManager()
    local sweep = Sweep.new()
    local data = {}
    
    -- Periodic data save
    sweep:GiveInterval(30, function()
        for key, value in pairs(data) do
            -- Save data
            print("Saving", key, value)
        end
    end)
    
    -- Cleanup on destroy
    sweep:GiveTask(function()
        return function()
            -- Final save
            for key, value in pairs(data) do
                print("Final save", key, value)
            end
            table.clear(data)
        end
    end)
    
    return {
        set = function(key, value)
            data[key] = value
        end,
        get = function(key)
            return data[key]
        end,
        destroy = function()
            sweep:Clean()
        end
    }
end
```

## Best Practices

### Task Organization

1. Group Related Tasks:
   ```lua
   -- Good: Related tasks grouped together
   sweep:GiveTask(function()
       local conn1 = obj.Event1:Connect(handler1)
       local conn2 = obj.Event2:Connect(handler2)
       return function()
           conn1:Disconnect()
           conn2:Disconnect()
       end
   end)
   
   -- Bad: Separate tasks for related operations
   sweep:GiveTask(obj.Event1:Connect(handler1))
   sweep:GiveTask(obj.Event2:Connect(handler2))
   ```

2. Use Labels for Important Tasks:
   ```lua
   sweep:GiveTask(
       workspace.ChildAdded:Connect(handleChild),
       "child_handler"
   )
   ```

3. Clean Up Early:
   ```lua
   local taskId = sweep:GiveTask(heavyOperation)
   -- ... use the operation ...
   sweep[taskId] = nil  -- Clean up when no longer needed
   ```

### Memory Management

1. Avoid Circular References:
   ```lua
   -- Good: Use weak references when needed
   local weak = setmetatable({}, { __mode = "v" })
   sweep:GiveTask(function()
       weak.ref = someObject
   end)
   ```

2. Clear Tables:
   ```lua
   sweep:GiveTask(function()
       return function()
           table.clear(largeTable)
       end
   end)
   ```

3. Handle Large Resources:
   ```lua
   sweep:GiveTask(function()
       local resource = loadLargeResource()
       return function()
           resource:Destroy()
           resource = nil
       end
   end)
   ```

## Debugging

### Enable Debug Mode

```lua
-- In ReplicatedStorage
local debug = Instance.new("BoolValue")
debug.Name = "Debug"
debug.Value = true
debug.Parent = game:GetService("ReplicatedStorage")
```

### Track Task Lifecycles

```lua
local function debugTask(task, label)
    return function()
        print("Starting task:", label)
        task()
        print("Completed task:", label)
    end
end

sweep:GiveTask(debugTask(function()
    -- Task code
end, "important_operation"))
```

### Monitor Task Count

```lua
local function printTaskCount(sweep)
    local count = 0
    for _ in pairs(sweep._tasks) do
        count = count + 1
    end
    print("Current task count:", count)
end

-- Check task count periodically
sweep:GiveInterval(5, function()
    printTaskCount(sweep)
end)
```

### Performance Monitoring

```lua
local function monitorTaskPerformance(sweep)
    local startTime = os.clock()
    local taskCount = 0
    
    -- Override GiveTask to track performance
    local originalGiveTask = sweep.GiveTask
    sweep.GiveTask = function(self, task, label)
        taskCount = taskCount + 1
        local taskStartTime = os.clock()
        
        local wrappedTask = function()
            local success, result = pcall(task)
            if not success then
                warn("Task failed:", label, result)
            end
            print(string.format(
                "Task %s took %.3f seconds",
                label or "unknown",
                os.clock() - taskStartTime
            ))
        end
        
        return originalGiveTask(self, wrappedTask, label)
    end
    
    -- Report statistics on cleanup
    local originalClean = sweep.Clean
    sweep.Clean = function(self)
        print(string.format(
            "Sweep lifetime: %.2f seconds, Tasks handled: %d",
            os.clock() - startTime,
            taskCount
        ))
        return originalClean(self)
    end
end 
``` 
