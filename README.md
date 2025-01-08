# Sweep Framework

A powerful and efficient task management and cleanup utility for Roblox, with built-in Knit integration.

## Features

- 🧹 Efficient resource cleanup and management
- 🔄 Automatic connection handling
- ⚡ Promise integration
- ⏱️ Interval task management
- 🏷️ Task labeling for debugging
- 🛠️ Seamless Knit framework integration

## Installation

1. Add the Sweep framework to your Roblox project
2. Ensure you have the required dependencies:
   - Knit framework
   - (Optional) ProfileStore

## Quick Start
```lua
local Sweep = require(ReplicatedStorage.Packages.Sweep)

-- Create a new Sweep instance
local sweep = Sweep.new()

-- Add tasks for cleanup
sweep:GiveTask(function()
    print("Cleaning up!")
end)

-- Manage connections
sweep:GiveTask(workspace.ChildAdded:Connect(print))

-- Create interval tasks
sweep:GiveTask(sweep:GiveInterval(5, function()
    print("Running every 5 seconds")
end))

-- Clean up all tasks
sweep:Clean()
```

## Integration with Knit

```lua
-- Example Service Integration
local ExampleService = Knit.CreateService({
    Name = "ExampleService",
    Client = {},
})

function ExampleService:KnitInit()
    self._sweep = Sweep.new()
    
    -- Add cleanup tasks
    self._sweep:GiveTask(workspace.ChildAdded:Connect(function(child)
        print("New child added:", child.Name)
    end))
end

function ExampleService:Destroy()
    self._sweep:Clean()
end
```

## Documentation

For more information, please see:
- [Getting Started](docs/getting-started.md)
- [Technical Reference](docs/technical-reference.md)
- [Advanced Patterns](docs/advanced-patterns.md)

## License

MIT License - See LICENSE file for details

For more information, please see the [LICENSE](LICENSE.md)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 

For more information, please see [CONTRIBUTING.md](CONTRIBUTING.md)
