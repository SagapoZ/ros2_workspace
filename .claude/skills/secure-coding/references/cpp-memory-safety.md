# C++ Memory Safety Patterns

## 1. Lambda 引用捕获悬空

本项目最常见的悬空引用模式：

```cpp
// WRONG — lambda [&] 捕获了局部变量，在异步回调中使用
void ProcessSegments()
{
    double dec_scale = 0.0;  // 栈上变量
    auto callback = [&](Type type)
    {  // dec_scale 被引用捕获
        data[type].push_back(dec_scale);  // 异步回调时 dec_scale 已析构！
    };
    timer.RegisterCallback(callback);  // 注册到异步定时器
}

// RIGHT — 值捕获
void ProcessSegments()
{
    double dec_scale = 0.0;
    auto callback = [dec_scale](Type type)
    {  // 值捕获，lambda 拥有副本
        data[type].push_back(dec_scale);
    };
    timer.RegisterCallback(callback);
}

// RIGHT — 同步调用可安全使用 [&]
void ProcessSegments()
{
    double dec_scale = 0.0;
    auto immediate = [&](Type type)
    {  // OK — 立即调用
        data[type].push_back(dec_scale);
    };
    immediate(Type::k_Force);  // lambda 在 dec_scale 生命周期内执行
}
```

## 2. 指针解引用

```cpp
// WRONG
Eigen::Vector3d pt = VisualTech::GetInstance()->QueryPointPosition(name);
double x = pt[0];  // 没判空！可能返回 (-1,-1,-1) 表示查询失败

// RIGHT
Eigen::Vector3d pt = VisualTech::GetInstance()->QueryPointPosition(name);
if (pt[0] == -1 && pt[1] == -1 && pt[2] == -1)
{
    // 查询失败，标记无效
    return;
}

// WRONG
auto* derived = dynamic_cast<DerivedType*>(base_ptr);
derived->Method();  // 没判空！

// RIGHT
auto* derived = dynamic_cast<DerivedType*>(base_ptr);
if (derived)
{
    derived->Method();
}

// WRONG — shared_ptr 循环引用导致内存泄漏
class A
{
    std::shared_ptr<B> b_;
};
class B
{
    std::shared_ptr<A> a_;  // 循环！
};

// RIGHT — 一方用 weak_ptr 打破循环
class B
{
    std::weak_ptr<A> a_;
};
```

## 3. 不安全字符串操作

```cpp
// WRONG — 禁止使用
sprintf(buf, "%s", input);
strcpy(dest, src);
strcat(dest, src);
gets(buf);

// RIGHT — 使用安全替代
snprintf(buf, sizeof(buf), "%s", input);
strncpy(dest, src, sizeof(dest) - 1);
dest[sizeof(dest) - 1] = '\0';
// 或直接用 std::string
```

## 4. 多线程数据竞争

```cpp
// WRONG — 共享数据未保护
double shared_force_;  // RT 线程写
void UpdateCallback()
{
    shared_force_ = ComputeForce();  // 非 RT 线程读 — 竞态！
}

// RIGHT — 使用 RealtimeBuffer 或 atomic
realtime_tools::RealtimeBuffer<double> shared_force_buf_;
std::atomic<double> shared_force_atomic_;  // 仅简单类型适合
```

## 5. Eigen 矩阵使用

```cpp
// WRONG — RT 线程中动态分配
Eigen::MatrixXd J(6, joint_num);  // heap allocation!

// RIGHT — 固定大小矩阵或 static 预分配
Eigen::Matrix<double, 6, Eigen::Dynamic, Eigen::ColMajor, 6, Eigen::Dynamic> J(6, joint_num);
// 或
static Eigen::MatrixXd J(6, joint_num_);
```
