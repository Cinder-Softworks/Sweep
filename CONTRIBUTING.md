# Contributing to Sweep

We love your input! We want to make contributing to Sweep as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with Github
We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## We Use [Github Flow](https://docs.github.com/en/get-started/using-github/github-flow)
Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code follows the existing style.
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License
In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using Github's [issue tracker](../../issues)
We use GitHub issues to track public bugs. Report a bug by [opening a new issue](../../issues/new); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Code Style Guidelines

### Lua Style Guide

1. Use PascalCase for class names and methods
2. Use camelCase for variables and functions
3. Use UPPER_CASE for constants
4. Indent using 4 spaces
5. End files with a newline

Example:
```lua
local DEFAULT_TIMEOUT = 5

local function doSomething()
    -- Function body
end

local MyClass = {}
MyClass.__index = MyClass

function MyClass.new()
    local self = setmetatable({}, MyClass)
    return self
end

function MyClass:DoSomething()
    -- Method body
end

return MyClass
```

### Documentation Style

1. Use [LuaDoc](https://keplerproject.github.io/luadoc/) style comments
2. Document all public APIs
3. Include examples in documentation
4. Keep line length under 100 characters

Example:
```lua
--[=[
    Creates a new instance of MyClass.
    @return MyClass -- The new instance
]=]
function MyClass.new()
    -- Implementation
end

--[=[
    Does something important.
    @param value number -- The value to process
    @return boolean -- Whether the operation succeeded
]=]
function MyClass:DoSomething(value)
    -- Implementation
end
```

## Testing

1. Write tests for new features
2. Update tests when modifying existing features
3. Ensure all tests pass before submitting a pull request

## License
By contributing, you agree that your contributions will be licensed under its MIT License. 
