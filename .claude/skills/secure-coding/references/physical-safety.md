# Physical Safety Patterns

机器人按摩系统的物理安全是最高优先级。任何软件 bug 都可能导致人身伤害。

## 1. 力/力矩硬限制

```cpp
// WRONG — 调整后的力没有硬上限
double adjusted_force = origin_fd * factor;
return adjusted_force;  // factor 计算错误可能导致超大输出力

// RIGHT — 双层保护
double adjusted_force = origin_fd * factor;
// 层1: 不低于最小力
adjusted_force = std::max(gconfig.min_force, adjusted_force);
// 层2: 不高于最大允许力 (硬限制)
constexpr double kMaxForceN = 80.0;  // 硬件最大允许力
adjusted_force = std::min(kMaxForceN, adjusted_force);
return adjusted_force;
```

## 2. 急停路径检查

```cpp
// WRONG — 急停逻辑中有阻塞操作
void EmergencyStop()
{
    ros::Duration(0.5).sleep();  // 阻塞！每 ms 都关键
    SetForce(0);
}

// RIGHT — 急停直达，无阻塞
void EmergencyStop()
{
    force_cmd_ = 0.0;              // 立即置零
    SendCmdImmediate(force_cmd_);  // 直接发送
    tool_enabled_ = false;         // 关闭工具
}

// WRONG — catch 块中没有安全处理
try
{
    adjusted_force = ComputeAdjustForce(origin_fd, pose);
}
catch (...)
{
    // 异常后直接返回原始力，可能过大
    return origin_fd;
}

// RIGHT — 异常兜底用安全值
try
{
    adjusted_force = ComputeAdjustForce(origin_fd, pose);
}
catch (...)
{
    ROS_ERROR("Force adjust failed, using min force");
    return gconfig.min_force;  // 安全兜底
}
```

## 3. 参数范围验证（YAML 加载时）

```cpp
// RIGHT — 加载后立即校验
void DesiredForceAdjuster::ParseNode(const YAML::Node& node)
{
    config.max_force_decrease_scale = node["max_force_decrease_scale"].as<double>();
    // 范围检查
    if (config.max_force_decrease_scale < 0.0 || config.max_force_decrease_scale > 1.0)
    {
        ROS_FATAL("max_force_decrease_scale must be in [0,1], got %f",
                  config.max_force_decrease_scale);
        config.max_force_decrease_scale = 0.5;  // 安全默认值
    }

    config.min_force = node["min_force"].as<double>();
    if (config.min_force < 0 || config.min_force > 100)
    {
        ROS_FATAL("min_force out of range");
        config.min_force = 5.0;
    }

    // 交叉校验
    if (config.max_force_decrease_scale > 0.8)
    {
        ROS_WARN("Very high force decrease scale %f — verify safety",
                 config.max_force_decrease_scale);
    }
}
```

## 4. 视觉查询失败时的安全处理

```cpp
// WRONG — 视觉查询失败时静默跳过
pt = VisualTech::GetInstance()->QueryPointPosition(name);
// (-1,-1,-1) 被当作正常坐标使用，可能导致碰撞

// RIGHT — 明确处理失败
pt = VisualTech::GetInstance()->QueryPointPosition(name);
if (pt[0] == -1 && pt[1] == -1 && pt[2] == -1)
{
    ROS_ERROR("Failed to query point: %s", name.c_str());
    // 方案1: 标记无效，跳过该段
    segment.valid = false;
    // 方案2: 终止轨迹执行
    AbortTrajectory();
}
```

## 5. 碰撞检测

```cpp
// RIGHT — 关键位置检查碰撞风险
if (dist < tool_radius)
{  // 工具与骨头重叠
    ROS_WARN_THROTTLE(1.0, "Tool too close to bone: dist=%f", dist);
    // 减小力 + 降低速度
    force_scale = std::min(force_scale, 0.3);
    velocity_scale = 0.1;
}
```
