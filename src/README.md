# ROS2 工作空间源码目录

本目录存放 ROS2 功能包（package）。

## 当前包

| 包名 | 说明 |
|------|------|
| `ros2_learning` | Python 学习示例包，发布者/订阅者 |
| `ros2_learning_cpp` | C++ 学习示例包，发布者/订阅者 |

## 构建与使用

```bash
# 在 ros2_workspace 根目录执行
source /opt/ros/humble/setup.bash
colcon build
source install/setup.bash
```

仅构建指定包：
```bash
colcon build --packages-select ros2_learning
colcon build --packages-select ros2_learning_cpp
```

## 添加新包

使用 `ros2 pkg create` 创建新包，或手动创建符合 ROS2 规范的目录结构。
