# Project Coding Standards Reference

These are the mandatory coding standards for this codebase. Flag deviations as warnings unless marked critical.

## Formatting (from .clang-format)

- **Brace style**: Allman/BSD — ALL braces go on new lines (AfterClass, AfterControlStatement, AfterFunction, AfterNamespace, BeforeCatch, BeforeElse)
- **Indentation**: 4 spaces, access modifiers offset -4 (align with `class` keyword)
- **Column limit**: No hard limit set in root .clang-format (ColumnLimit: 10000), but keep lines reasonably short (100-120 chars)
- **Short functions**: Only inline class methods allowed on single line (`AllowShortFunctionsOnASingleLine: InlineOnly`)

```cpp
// CORRECT
class MyClass
{
public:
    void foo();
private:
    int bar_;
};

void myFunction()
{
    if (condition)
    {
        // code
    }
}
```

## Naming Conventions (Google C++ Style)

- **Classes/Structs**: `PascalCase` (e.g., `ForceSensorCalibration`)
- **Functions/Methods**: `PascalCase` (e.g., `GetValue()`, `ProcessData()`)
- **Variables**: `snake_case` (e.g., `force_threshold_`, `robot_state`)
- **Member variables**: `snake_case_` with trailing underscore (e.g., `config_ptr_`)
- **Constants/Enums**: `kPascalCase` or `ALL_CAPS` (e.g., `kMaxRetries`, `MAX_RETRIES`)
- **Namespaces**: `snake_case` (e.g., `ethercat_devices`)
- **File names**: `snake_case.h` / `snake_case.cpp`

## Project-Specific Patterns

### Includes
- Use full paths relative to the package include directory
- Order: related header → C system headers → C++ standard library → other libraries → project headers
- Use `#pragma once` or include guards consistently

### Namespaces
- Each package uses its own namespace matching the package name (e.g., `namespace config_manager`)
- Do NOT use `using namespace` in header files
- Close namespace with comment: `}  // namespace config_manager`

### ROS Logging
- Use `ROS_DEBUG`/`ROS_INFO`/`ROS_WARN`/`ROS_ERROR`/`ROS_FATAL` — NOT printf/cout
- **CRITICAL**: Do NOT use ROS logging in real-time control loops or callbacks — use `realtime_log` from `infra` package instead
- `ROS_INFO` is acceptable in initialization, config loading, and non-realtime code paths

### Real-Time Safety (controllers, hardware interface)
- No dynamic memory allocation (`new`, `malloc`, `std::vector::push_back`) in real-time paths
- No blocking I/O in real-time callbacks
- No ROS logging in real-time control loops
- Use `realtime_tools::RealtimeBuffer` or similar for thread-safe data exchange
- Pre-allocate buffers in initialization

### Error Handling
- Use `CHECK`/`DCHECK` for invariants that should never fail
- Return error codes or use exceptions consistently within a module
- Do NOT ignore return values from ROS service calls or hardware operations
- Always check pointers before dereferencing, especially from ROS parameter server or service responses
