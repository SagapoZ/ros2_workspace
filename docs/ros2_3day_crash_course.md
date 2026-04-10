# ROS2 三天入门训练营

面向 ROS1 开发者的快速入门，目标：3 天内掌握 ROS2 核心概念，为系统迁移做准备。

**前置**：已有 ROS1 经验，熟悉节点、话题、服务等概念。

---

## 训练概览


| 天数    | 主题                  | 预计时长   |
| ----- | ------------------- | ------ |
| Day 1 | 工作空间、包、节点、话题        | 4–5 小时 |
| Day 2 | 服务、参数、Launch、Action | 4–5 小时 |
| Day 3 | ROS1→ROS2 迁移实战      | 4–5 小时 |


---

## Day 1：基础拓扑与通信

### 1.1 ROS1 vs ROS2 核心差异（15 分钟）


| 概念     | ROS1          | ROS2           |
| ------ | ------------- | -------------- |
| 构建系统   | catkin        | ament + colcon |
| 主节点    | roscore（必须）   | 无，DDS 直连       |
| 包格式    | package.xml 2 | package.xml 3  |
| 消息定义   | .msg 同目录      | 独立 interface 包 |
| 命名     | 有 / 前缀        | 无 / 也可，建议保留    |
| Python | rospy         | rclpy          |
| C++    | roscpp        | rclcpp         |


**关键变化**：ROS2 不再需要 roscore，节点通过 DDS 发现彼此。

### 1.2 工作空间与构建（30 分钟）

```bash
cd /home/robot/ros2_workspace
source /opt/ros/humble/setup.bash

# 构建（类比 catkin_make）
colcon build

# 只构建指定包
colcon build --packages-select ros2_learning ros2_learning_cpp

# 加载工作空间（每次新终端都要）
source install/setup.bash
```

**对照**：`catkin_make` → `colcon build`，`devel/setup.bash` → `install/setup.bash`。

### 1.3 包与节点（30 分钟）

```bash
# 创建 C++ 包
ros2 pkg create my_pkg --build-type ament_cmake --node-name my_node -- my_pkg

# 创建 Python 包
ros2 pkg create my_py_pkg --build-type ament_python -- my_py_pkg

# 运行节点
ros2 run <package_name> <executable_name>
```

**动手**：用 `ros2 run ros2_learning publisher` 和 `ros2 run ros2_learning subscriber` 跑通发布/订阅。

### 1.4 话题与消息（1 小时）

```bash
# 查看话题
ros2 topic list
ros2 topic info /learning_topic
ros2 topic echo /learning_topic

# 发布（--once 发一次）
ros2 topic pub /learning_topic std_msgs/msg/String "data: 'hello'" --once

# 查看消息类型
ros2 interface show std_msgs/msg/String
```

**消息类型变化**：`std_msgs/String` → `std_msgs/msg/String`（Python/C++ 中为 `std_msgs.msg.String`）。

### 1.5 动手练习（1–2 小时）

1. 用 `ros2 topic echo` 观察 `ros2_learning` 的 publisher 输出。
2. 用 `ros2 topic pub` 手动发一条消息，确认 subscriber 能收到。
3. 阅读 `src/ros2_learning/ros2_learning/learning_publisher.py`，理解 `create_publisher`、`create_timer`。
4. 阅读 `src/ros2_learning_cpp/src/publisher.cpp`，对比 C++ 写法。
5. 在 `my_package` 中修改 `my_node.cpp`，改为发布 `std_msgs/msg/String` 到 `my_topic`。

### Day 1 自测

- 能独立用 `colcon build` 构建并 `source` 工作空间
- 能解释 ROS2 不需要 roscore 的原因
- 能使用 `ros2 topic list/echo/pub` 操作话题
- 能区分 `ament_cmake` 与 `ament_python` 包结构

---

## Day 2：服务、参数与 Launch

### 2.1 服务（Service）（1 小时）

```bash
# 查看服务
ros2 service list
ros2 service type /add_two_ints

# 调用服务（ROS2 用 YAML 格式）
ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 1, b: 2}"
```

**对照**：`rosservice call` → `ros2 service call`，参数格式从空格分隔变为 YAML。

**动手**：运行 turtlesim 的服务示例：

```bash
ros2 run turtlesim turtlesim_node
# 新终端
ros2 service list
ros2 service call /turtle1/set_pen turtlesim/srv/SetPen "{r: 255, g: 0, b: 0, width: 3}"
```

### 2.2 参数（Parameter）（45 分钟）

```bash
# 查看节点参数
ros2 param list
ros2 param get /node_name param_name

# 设置参数（运行前）
ros2 run pkg node --ros-args -p param_name:=value

# 运行中设置
ros2 param set /node_name param_name value
```

**对照**：`rosparam` → `ros2 param`，参数可动态加载、有类型。

### 2.3 Launch 文件（1 小时）

ROS2 使用 Python 写 launch，替代 XML。

```python
# my_launch.py
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(package='ros2_learning', executable='publisher', name='pub'),
        Node(package='ros2_learning', executable='subscriber', name='sub'),
    ])
```

```bash
ros2 launch <package> my_launch.py
```

**对照**：`roslaunch pkg file.launch` → `ros2 launch pkg file.py`。

### 2.4 动作（Action）（30 分钟）

Action = 带反馈的长时间任务（类似 ROS1 action）。

```bash
ros2 action list
ros2 action send_goal /turtle1/rotate_absolute turtlesim/action/RotateAbsolute "{theta: 1.57}"
```

### 2.5 动手练习（1–2 小时）

1. 用 turtlesim 练习 `ros2 service call` 和 `ros2 param set`。
2. 在 `ros2_learning` 包中新增 `launch/learning.launch.py`，同时启动 publisher 和 subscriber。
3. 在 `setup.py` 中注册 launch 文件，用 `ros2 launch ros2_learning learning.launch.py` 运行。

### Day 2 自测

- 能调用服务并理解 YAML 参数格式
- 能使用 `ros2 param` 查看和设置参数
- 能编写并运行 Python launch 文件
- 知道 Action 的用途和基本命令

---

## Day 3：ROS1 → ROS2 迁移实战

### 3.1 概念对照表


| ROS1                           | ROS2                         |
| ------------------------------ | ---------------------------- |
| `roscore`                      | 不需要                          |
| `catkin_make` / `catkin build` | `colcon build`               |
| `rospy`                        | `rclpy`                      |
| `roscpp`                       | `rclcpp`                     |
| `rospy.Publisher`              | `node.create_publisher()`    |
| `rospy.Subscriber`             | `node.create_subscription()` |
| `rospy.Service`                | `node.create_service()`      |
| `rospy.init_node()`            | `rclpy.init()` + `Node()`    |
| `rospy.spin()`                 | `rclpy.spin(node)`           |
| `std_msgs/String`              | `std_msgs/msg/String`        |
| `sensor_msgs/Image`            | `sensor_msgs/msg/Image`      |
| `tf`                           | `tf2_ros`                    |
| `dynamic_reconfigure`          | `rclcpp::Parameter`          |


### 3.2 消息/服务迁移

- **标准消息**：多数 `std_msgs`、`sensor_msgs`、`geometry_msgs` 可直接用，包名改为 `xxx/msg/Type` 或 `xxx/srv/Type`。
- **自定义消息**：需建 `xxx_interfaces` 包，用 `ament_cmake` + `rosidl`，`.msg`/`.srv` 放 `msg/`、`srv/` 目录。
- **字段变化**：检查 [REP](https://www.ros.org/reps/) 和 [migration guide](https://docs.ros.org/en/humble/How-To-Guides/Migrating-from-ROS1.html)。

### 3.3 Python 迁移要点

```python
# ROS1
import rospy
from std_msgs.msg import String
rospy.init_node('my_node')
pub = rospy.Publisher('topic', String, queue_size=10)
rospy.spin()

# ROS2
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
rclpy.init()
node = Node('my_node')
pub = node.create_publisher(String, 'topic', 10)
rclpy.spin(node)
```

要点：用 `Node` 类、`create_publisher`/`create_subscription`、`rclpy.spin(node)`。

### 3.4 C++ 迁移要点

```cpp
// ROS1
ros::init(argc, argv, "my_node");
ros::NodeHandle n;
ros::Publisher pub = n.advertise<std_msgs::String>("topic", 10);
ros::spin();

// ROS2
rclcpp::init(argc, argv);
auto node = std::make_shared<MyNode>();
rclcpp::spin(node);
```

要点：用 `rclcpp::Node` 继承、`create_publisher`、`rclcpp::spin`。

### 3.5 迁移检查清单

- 工作空间用 `colcon build` 构建
- 所有包有 `package.xml` format 3
- 自定义消息/服务已迁移到 interface 包
- Python 用 `rclpy`，C++ 用 `rclcpp`
- Launch 从 XML 改为 Python
- `tf` 改为 `tf2_ros`
- 参数用 `declare_parameter` / `get_parameter`
- 移除对 `roscore` / `master` 的依赖

### 3.6 动手练习（2–3 小时）

1. **选一个简单 ROS1 节点**（如只有 pub/sub 的节点）。
2. **新建 ROS2 包**，用 `ros2 pkg create` 或参考 `docs/manual_create_ros2_package.md`。
3. **逐行迁移**：替换 API，调整消息类型。
4. **构建并运行**，用 `ros2 topic echo` 验证。
5. **写 launch 文件**，一次性启动多个节点。

### 3.7 参考资源

- [ROS2 Humble 文档](https://docs.ros.org/en/humble/)
- [从 ROS1 迁移指南](https://docs.ros.org/en/humble/How-To-Guides/Migrating-from-ROS1.html)
- [ros1_bridge](https://github.com/ros2/ros1_bridge)（ROS1 与 ROS2 共存时桥接）

---

## 本工作空间资源


| 路径                                   | 说明                          |
| ------------------------------------ | --------------------------- |
| `src/ros2_learning/`                 | Python 发布者/订阅者示例            |
| `src/ros2_learning_cpp/`             | C++ 发布者/订阅者示例               |
| `src/my_package/`                    | `ros2 pkg create` 生成的 C++ 包 |
| `docs/manual_create_ros2_package.md` | 手动创建包教程                     |
| `docs/windows_wsl_setup.md`          | Windows/WSL 环境配置            |


---

## 每日时间建议


| 时段  | 内容          |
| --- | ----------- |
| 上午  | 阅读文档 + 跑通示例 |
| 下午  | 动手练习 + 改代码  |
| 晚上  | 自测 + 整理笔记   |


三天后应能：独立创建包、编写节点、使用 topic/service/param、编写 launch，并完成一个简单 ROS1 节点的迁移。