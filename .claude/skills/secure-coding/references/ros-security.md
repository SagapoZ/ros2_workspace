# ROS-Specific Security Patterns

## 1. 订阅者消息校验

```cpp
// WRONG — 信任外部消息不做校验
void ForceCmdCallback(const std_msgs::Float64& msg)
{
    target_force_ = msg.data;  // 攻击者发送 NaN/Inf/负数
}

// RIGHT — 订阅回调中校验
void ForceCmdCallback(const std_msgs::Float64& msg)
{
    if (std::isnan(msg.data) || std::isinf(msg.data))
    {
        ROS_WARN_THROTTLE(1.0, "Invalid force command: %f", msg.data);
        return;
    }
    if (msg.data < 0.0 || msg.data > kMaxForceN)
    {
        ROS_WARN_THROTTLE(1.0, "Force out of range: %f", msg.data);
        return;
    }
    target_force_ = msg.data;
}

// WRONG — 字符串消息无长度限制
void PathCallback(const std_msgs::String& msg)
{
    std::string path = msg.data;  // 可能极大或包含注入字符
}

// RIGHT — 长度和内容校验
void PathCallback(const std_msgs::String& msg)
{
    if (msg.data.size() > 256)
    {
        ROS_WARN("Path too long: %zu chars", msg.data.size());
        return;
    }
    if (msg.data.find("..") != std::string::npos)
    {
        ROS_WARN("Path traversal attempt: %s", msg.data.c_str());
        return;
    }
}
```

## 2. 参数服务器安全

```cpp
// WRONG — 参数未校验直接使用
double width;
ros::param::get("~adjust_width", width);  // 可能未设置、负值、超大值

// RIGHT — 带默认值 + 范围校验
double width = ros::param::param<double>("~adjust_width", 0.03);
if (width < 0.005 || width > 0.5)
{
    ROS_WARN("adjust_width %f out of [0.005, 0.5], using default 0.03", width);
    width = 0.03;
}
```

## 3. 服务调用安全

```cpp
// WRONG — 无限阻塞
bool success = visual_client_.Call(srv);

// RIGHT — 超时 + 错误处理
if (!visual_client_.WaitForExistence(ros::Duration(2.0)))
{
    ROS_ERROR("Visual service not available");
    return false;
}
if (!visual_client_.Call(srv))
{
    ROS_ERROR("Visual service call failed");
    return false;
}
// 校验返回结果
if (srv.response.points.empty())
{
    ROS_WARN("Visual service returned empty result");
    return false;
}
```

## 4. Topic 频率保护

```cpp
// RIGHT — 防止高频消息导致资源耗尽
ros::Time last_msg_time_;
const ros::Duration kMinInterval(0.01);  // 100Hz 上限

void HighFreqCallback(const sensor_msgs::PointCloud2& msg)
{
    ros::Time now = ros::Time::now();
    if (now - last_msg_time_ < kMinInterval)
    {
        return;  // 丢弃过密的消息
    }
    last_msg_time_ = now;
    Process(msg);
}
```

## 5. 实时发布者保护

```cpp
// RIGHT — 频率限制发布
ros::Time last_publish_time_{0.0};

void PublishAdjustParam(const RTAdjustParam& param)
{
    if ((ros::Time::now() - last_publish_time_).toSec() > 0.1)
    {  // 10Hz
        rt_publisher_->PublishRtAdjustParam(param);
        last_publish_time_ = ros::Time::now();
    }
}
```
