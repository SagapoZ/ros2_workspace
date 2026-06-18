# Injection Defense Patterns

## 1. 命令注入

```cpp
// WRONG — YAML 字段直接拼接到命令中
std::string cmd = "docker exec test_docker bash -c 'cat " +
                  config.recorded_data_and_config_path + "/data.csv'";
system(cmd.c_str());  // 路径包含恶意字符时可能注入！

// WRONG — ROS 消息字段拼接
void MsgCallback(const std_msgs::String& msg)
{
    std::string cmd = "echo " + msg.data + " > /tmp/log";
    system(cmd.c_str());  // msg.data = "; rm -rf /" 可注入！
}

// RIGHT — 使用参数化/白名单验证
void SafeExec(const std::string& path)
{
    // 白名单：只允许字母、数字、下划线、斜杠
    if (path.find_first_not_of("abcdefghijklmnopqrstuvwxyz"
                                "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                "0123456789/_.") != std::string::npos)
    {
        ROS_ERROR("Invalid path characters");
        return;
    }
    // 或避免 system()，使用 fork+exec 系列
}
```

## 2. 文件路径遍历

```cpp
// WRONG — 用户输入路径直接使用
std::string filename = ros::param::param<std::string>("~output_file", "default.csv");
std::ofstream out(filename);  // 可能写入 /etc/passwd!

// RIGHT — 限制在允许目录内
std::string filename = SanitizeFilename(raw_name);
std::string full_path = "/allowed/data/dir/" + filename;
// 规范化后校验仍在目标目录下
if (full_path.find("/allowed/data/dir/") != 0)
{
    ROS_ERROR("Path traversal detected");
    return;
}
```

## 3. YAML 特殊处理

```cpp
// WRONG — 信任 YAML 字段不做校验
double width = seg_node["width"].as<double>();  // 负数？极大值？NaN？
double force = config["min_force"].as<double>(); // 可能为负或极大

// RIGHT — 范围校验
double width = seg_node["width"].as<double>();
if (width < 0.0 || width > 1.0)
{  // 0~1m 合理范围
    ROS_WARN("Invalid width: %f, using default", width);
    width = 0.03;
}
double force = config["min_force"].as<double>();
if (force < 0.0 || force > 200.0)
{
    ROS_WARN("Invalid min_force: %f", force);
    force = 5.0;
}
```

## 4. Docker exec 安全（本项目特有）

```cpp
// WRONG — 用户可控内容拼入 docker exec
std::string pkg = ros::param::param<std::string>("~pkg", "");
std::string cmd = "docker exec test_docker catkin_make -DCATKIN_WHITELIST_PACKAGES=" + pkg;
system(cmd.c_str());

// RIGHT — 白名单验证
const std::vector<std::string> kAllowedPkgs = {"massage_controller", "safety_controller"};
if (std::find(kAllowedPkgs.begin(), kAllowedPkgs.end(), pkg) == kAllowedPkgs.end())
{
    ROS_ERROR("Unknown package: %s", pkg.c_str());
    return;
}
```
