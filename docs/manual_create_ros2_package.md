# 手动创建 ROS2 包教程

本教程教你从零手动创建 ROS2 包，不依赖 `ros2 pkg create` 命令，便于理解包的结构与各文件作用。

---

## 一、ROS2 包的类型

| 类型 | 构建系统 | 适用语言 |
|------|----------|----------|
| `ament_python` | setuptools | Python |
| `ament_cmake` | CMake | C++ |

一个包只能选择一种类型。下面分别介绍两种包的手动创建流程。

---

## 二、手动创建 Python 包

### 2.1 目录结构

```
my_python_pkg/
├── package.xml          # 包元信息
├── setup.py             # Python 包配置
├── setup.cfg             # setuptools 配置
├── resource/
│   └── my_python_pkg    # 空文件，包名标记
└── my_python_pkg/       # Python 模块目录（与包名一致）
    ├── __init__.py
    └── my_node.py       # 你的节点代码
```

### 2.2 创建步骤

**步骤 1：创建目录**

```bash
cd /home/robot/ros2_workspace/src
mkdir -p my_python_pkg/resource
mkdir -p my_python_pkg/my_python_pkg
```

**步骤 2：创建 `package.xml`**

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>my_python_pkg</name>
  <version>0.1.0</version>
  <description>我的 Python 包描述</description>
  <maintainer email="you@example.com">Your Name</maintainer>
  <license>Apache-2.0</license>

  <depend>rclpy</depend>
  <depend>std_msgs</depend>

  <export>
    <build_type>ament_python</build_type>
  </export>
</package>
```

**步骤 3：创建 `setup.py`**

```python
from setuptools import setup

package_name = 'my_python_pkg'

setup(
    name=package_name,
    version='0.1.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Your Name',
    maintainer_email='you@example.com',
    description='我的 Python 包',
    license='Apache-2.0',
    entry_points={
        'console_scripts': [
            'my_node = my_python_pkg.my_node:main',
        ],
    },
)
```

**步骤 4：创建 `setup.cfg`**

```ini
[develop]
script_dir=$base/lib/my_python_pkg
[install]
install_scripts=$base/lib/my_python_pkg
```

**步骤 5：创建 `resource/my_python_pkg`**

```bash
touch my_python_pkg/resource/my_python_pkg
# 空文件即可，用于 ament 索引
```

**步骤 6：创建 Python 模块**

`my_python_pkg/__init__.py`（可为空）：
```python
"""my_python_pkg 模块"""
```

`my_python_pkg/my_node.py`：
```python
#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from std_msgs.msg import String


class MyNode(Node):
    def __init__(self):
        super().__init__('my_node')
        self.pub = self.create_publisher(String, 'my_topic', 10)
        self.timer = self.create_timer(1.0, self.callback)
        self.count = 0

    def callback(self):
        msg = String()
        msg.data = f'Count: {self.count}'
        self.pub.publish(msg)
        self.get_logger().info(msg.data)
        self.count += 1


def main(args=None):
    rclpy.init(args=args)
    node = MyNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
```

**步骤 7：构建与运行**

```bash
cd /home/robot/ros2_workspace
source /opt/ros/humble/setup.bash
colcon build --packages-select my_python_pkg
source install/setup.bash
ros2 run my_python_pkg my_node
```

---

## 三、手动创建 C++ 包

### 3.1 目录结构

```
my_cpp_pkg/
├── CMakeLists.txt       # CMake 构建配置
├── package.xml          # 包元信息
└── src/
    └── my_node.cpp      # 你的节点代码
```

### 3.2 创建步骤

**步骤 1：创建目录**

```bash
cd /home/robot/ros2_workspace/src
mkdir -p my_cpp_pkg/src
```

**步骤 2：创建 `package.xml`**

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>my_cpp_pkg</name>
  <version>0.1.0</version>
  <description>我的 C++ 包描述</description>
  <maintainer email="you@example.com">Your Name</maintainer>
  <license>Apache-2.0</license>

  <depend>rclcpp</depend>
  <depend>std_msgs</depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
```

**步骤 3：创建 `CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.8)
project(my_cpp_pkg)

# 编译选项
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# 查找依赖
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

# 创建可执行文件
add_executable(my_node src/my_node.cpp)
ament_target_dependencies(my_node rclcpp std_msgs)

# 安装
install(TARGETS my_node DESTINATION lib/${PROJECT_NAME})

ament_package()
```

**步骤 4：创建 `src/my_node.cpp`**

```cpp
#include <chrono>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

using namespace std::chrono_literals;

class MyNode : public rclcpp::Node
{
public:
  MyNode() : Node("my_node"), count_(0)
  {
    pub_ = this->create_publisher<std_msgs::msg::String>("my_topic", 10);
    timer_ = this->create_wall_timer(1s, std::bind(&MyNode::callback, this));
  }

private:
  void callback()
  {
    auto msg = std_msgs::msg::String();
    msg.data = "Count: " + std::to_string(count_);
    pub_->publish(msg);
    RCLCPP_INFO(this->get_logger(), "%s", msg.data.c_str());
    count_++;
  }

  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr pub_;
  rclcpp::TimerBase::SharedPtr timer_;
  size_t count_;
};

int main(int argc, char* argv[])
{
  rclcpp::init(argc, argv);
  auto node = std::make_shared<MyNode>();
  rclcpp::spin(node);
  rclcpp::shutdown();
  return 0;
}
```

**步骤 5：构建与运行**

```bash
cd /home/robot/ros2_workspace
source /opt/ros/humble/setup.bash
colcon build --packages-select my_cpp_pkg
source install/setup.bash
ros2 run my_cpp_pkg my_node
```

---

## 四、关键文件说明

| 文件 | 作用 |
|------|------|
| `package.xml` | 包名、版本、依赖、构建类型声明 |
| `setup.py` (Python) | 定义入口点，使 `ros2 run` 可执行节点 |
| `setup.cfg` (Python) | 指定脚本安装路径 |
| `resource/<包名>` (Python) | ament 资源索引，空文件 |
| `CMakeLists.txt` (C++) | 编译、链接、安装可执行文件 |

---

## 五、常用依赖

| 依赖 | 用途 |
|------|------|
| `rclpy` | Python ROS2 客户端库 |
| `rclcpp` | C++ ROS2 客户端库 |
| `std_msgs` | 标准消息类型（String、Int32 等） |
| `geometry_msgs` | 几何消息（Point、Pose、Twist 等） |
| `sensor_msgs` | 传感器消息（Image、LaserScan 等） |

---

## 六、快速对照表

| 操作 | Python | C++ |
|------|--------|-----|
| 创建节点 | `create_publisher` / `create_subscription` | 同左 |
| 依赖 | `rclpy` | `rclcpp` |
| 入口点 | `setup.py` 的 `entry_points` | `CMakeLists.txt` 的 `add_executable` |
| 安装 | `install` 自动处理 | `install(TARGETS ...)` |

---

## 七、参考示例

工作空间内已有完整示例：

- **Python**：`src/ros2_learning/`
- **C++**：`src/ros2_learning_cpp/`

可对照本教程边看边改，加深理解。
