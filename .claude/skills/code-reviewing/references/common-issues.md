# Common Issues Found in This Codebase

Issues that have been repeatedly observed. Flag these with high priority.

## Real-Time Safety Violations

### ROS Logging in Control Callbacks
```cpp
// WRONG — blocks in real-time callback
void MassageController::Update(const ros::Time& time, const ros::Duration& period)
{
    ROS_INFO("Updating controller state");  // I/O in RT thread!
}

// RIGHT — RT-safe alternatives (base macro or module-specific macros)
void MassageController::Update(const ros::Time& time, const ros::Duration& period)
{
    RT_LOG_INFO("Updating controller state");  // ✅ base: infra/realtime_log/realtime_log.h
}
// Module-specific RT-safe macros (preferred — add namespace prefix, no I/O blocking):
//   massage_controller:  MASSAGE_INFO/MASSAGE_WARN/...   (massage_controller/common_defines.h)
//   safety_controller:   SAFETY_RT_INFO/SAFETY_RT_WARN/... (safety_controller/safety_logger.h)
//   evt_hw:              EVTHW_INFO/EVTHW_WARN/...         (evt_hw/src/common_defines.h)
//
// ✅ preferred example:
// void MassageController::Update(...) {
//     MASSAGE_INFO("Updating controller state");
// }
```

### Dynamic Memory in Update Loops
```cpp
// WRONG — heap allocation in control loop
void Controller::Update()
{
    std::vector<double> temp(100);  // may allocate!
    Eigen::MatrixXd M(6, 6);       // dynamic allocation!
}

// RIGHT — pre-allocate as member variables
class Controller
{
private:
    std::vector<double> temp_;  // allocated once in constructor
    Eigen::Matrix<double, 6, 6> M_;  // fixed-size = no heap
};
```

## 本项目 RT 线程禁止项（massage_controller_v1 / safety_controller）

`massage_controller_v1` 运行在 **1kHz 硬实时循环**（周期 ~1ms）。`update()` 路径中的代码必须遵守以下约束：

### 禁止在 RT 线程中执行的操作
- `new` / `malloc` / 任何堆内存分配
- `std::string` 超过 SSO 阈值（15 字符）的构造（触发堆分配）
- `std::vector::push_back` 或任何容器扩容操作
- `std::map::clear()` — 释放红黑树内部节点
- 频繁执行文件 I/O、网络 I/O、`printf`、`MASSAGE_WARN`/`MASSAGE_ERROR` 等日志宏
- `ros::Time::now()` 密集调用（每次都是系统调用）
- `loadEndEffector()` 等硬件操作（已知耗时 ~50ms，是 RT 超时的常见根因）

### RT 安全模式
```cpp
// RIGHT — Eigen 动态矩阵用 static 预分配
static Eigen::MatrixXd J(6, joint_num_);

// RIGHT — 耗时统计用 RecordTimePointMap + PrintRecordTimePoint（零堆分配）
static std::map<std::string, ros::Time> time_point_map;
static std::vector<std::string> time_point_name;
RecordTimePointMap(time_point_map, time_point_name, "begin");

// RIGHT — std::map 只更新 value，不 clear()
time_point_map[key] = ros::Time::now();

// RIGHT — 字符串 key 保持 ≤15 字符以利用 SSO
RecordTimePointMap(time_point_map, time_point_name, "getJointState");  // 13 chars — OK

// WRONG — 超长 key 导致 SSO 失效
RecordTimePointMap(time_point_map, time_point_name, "this_key_is_too_long_for_sso");  // >15 chars!
```

### 已知高耗时操作
- `getToolManipulability()` — SVD/行列式计算
- `invKinToolPose()` — HQP 迭代 IK 求解
- 这两个函数不应在单帧内重复调用

## Thread Safety

### Shared State Without Mutex
```cpp
// WRONG — data race on shared state
void stateCallback(const std_msgs::String& msg) {
    shared_data_ = msg.data;  // subscriber thread writes
}
void controlLoop() {
    use(shared_data_);  // control thread reads — RACE!
}

// RIGHT — use mutex or RealtimeBuffer
realtime_tools::RealtimeBuffer<std::string> shared_data_buf_;
```

### Lock Order Inconsistency
Multiple mutexes must always be acquired in the same order across all code paths to prevent deadlocks.

## Memory and Resource Management

### Missing Virtual Destructors
```cpp
// WRONG — base class without virtual destructor
class BaseController {
public:
    ~BaseController() {}  // non-virtual!
};

// RIGHT
class BaseController {
public:
    virtual ~BaseController() = default;
};
```

### Raw Pointer Ownership
Raw pointers are common in this codebase (ROS1 style), but ownership must be clear:
- Use `std::unique_ptr`/`std::shared_ptr` for new code
- Document ownership for raw pointers: `// owned by RobotDriver`
- Delete owned resources in destructors

## ROS-Specific Issues

### Uninitialized ROS Node Handle
Always check that `ros::NodeHandle` is valid before using. Private node handles (`~`) should be constructed once.

### Missing ros::spinOnce in Loops
Control loops using `ros::Rate` must call `ros::spinOnce()` or use async spinner for subscriber callbacks to fire.

### Hardcoded Topic/Service Names
Use configurable parameters rather than hardcoded strings for topic names.

### Service Call Without Timeout
```cpp
// WRONG — blocks forever if service is down
client.call(srv);

// RIGHT
if (!client.call(srv)) {
    ROS_ERROR("Service call failed");
}
```
Or better: use persistent service connections with timeout.

## Control-Specific Issues

### Uninitialized Eigen Matrices
```cpp
// WRONG
Eigen::MatrixXd Kp;  // uninitialized!

// RIGHT
Eigen::MatrixXd Kp = Eigen::MatrixXd::Zero(6, 6);
```

### Singularity Unchecked
Inverse kinematics and Jacobian inversions should check for singular values and have fallback behavior.

### Force/Torque Sensor Readings Without Filtering
Raw FT sensor readings should be filtered. Use `digital_filter` package or the built-in `FxrKalmanFilter`.

## C++ Standards Usage

### Controllers Package: C++17 OK
The `controllers` package uses C++17. Features like `if constexpr`, structured bindings, `std::optional` are allowed there.

### Other Packages: C++11 Only
All other packages target C++11. Do NOT use C++14/17/20 features in those packages:
- No `auto` return type deduction (C++14)
- No `if constexpr` (C++17)
- No structured bindings (C++17)
- No `std::make_unique` (C++14) — use `new` or manual `unique_ptr` construction
- Lambda captures by move NOT available (`[x = std::move(x)]` is C++14)

## Type Safety (RTTI / dynamic_cast)

### dynamic_cast on Incompatible Concrete Object
```cpp
// WRONG — compiler can statically prove cast will never succeed → -Werror
struct Base { virtual ~Base() = default; };
struct Derived : Base { void Method() {} };
Base base;                                        // concrete Base, not Derived
auto* d = dynamic_cast<Derived*>(&base);          // always nullptr, compiler warns

// RIGHT — go through a pointer so compiler cannot statically prove failure
Base base;
Base* ptr = &base;                                // indirection hides concrete type
auto* d = dynamic_cast<Derived*>(ptr);
EXPECT_TRUE(d == nullptr);                        // ✅ nullptr check after cast
```

**Check pattern**: `dynamic_cast<Target*>(&concrete_obj)` where `concrete_obj` is declared as a type that is not `Target` or a derived class of `Target` — the compiler can prove the cast always fails. This is a `-Werror=dynamic_cast` under GCC and will block compilation.

## Compile-Time Warnings Under -Werror

### Unused-But-Set Variable (-Wunused-but-set-variable)
```cpp
// WRONG — pt assigned but never read → -Werror
auto result = Query("test");
bool valid = result.first;
Eigen::Vector3d pt = result.second;   // assigned, never used
EXPECT_FALSE(valid);

// RIGHT — don't extract unused fields
auto result = Query("test");
bool valid = result.first;
// result.second intentionally unused — only validating the flag
EXPECT_FALSE(valid);

// ALSO RIGHT — if the variable must exist for documentation, cast to void
auto result = Query("test");
bool valid = result.first;
Eigen::Vector3d pt = result.second;   // kept for clarity
(void)pt;                             // ✅ suppress unused-variable warning
EXPECT_FALSE(valid);
```

**Common trigger**: Downgrading C++17 structured bindings (`auto [a, b] = ...`) to C++14-compatible code with `std::pair`/`std::tuple` extraction, where one field is needed but the other is not. Always check that every extracted variable is actually read.
