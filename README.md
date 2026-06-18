# ros2_workspace

ROS 2 (Jazzy) 学习与开发环境：容器镜像、一键脚本，以及示例/子项目的壳工程。

## 目录结构

```
ros2_workspace
├── docker/
│   ├── Dockerfileros2.dockerfile     # ROS 2 Jazzy 开发镜像
│   ├── docker-compose.ros2.yml       # Linux / WSL2 启动配置
│   └── envs/                          # compose 引入的 env 文件
├── docs/                             # 入门 / 配置文档
├── scripts/
│   └── install-starship-in-container.sh
├── build_docker.sh                  # Docker 环境管理一键脚本（仅 Linux/WSL2）
├── make_project.sh                  # 容器内编译 / 测试一键脚本
├── src/
│   ├── family_foundation/            # 基础层示例包（rclcpp 等）
│   └── family_public/                # 公共消息/接口包
├── .dockerignore                    # 构建上下文裁剪
└── README.md
```

仓库代码在宿主机与容器中均位于 `/home/robot/ros2_workspace`（容器内由 `/home/robot/easefuture/` 挂载而来），路径统一，便于迁移。

## 镜像简介

- 基础镜像 `osrf/icra2023_ros2_gz_tutorial:roscon2024_tutorial_nvidia`，预装 ROS 2 Jazzy + Gazebo + NVIDIA 支持（可用 `BASE_IMAGE` 覆盖）；
- 使用清华 apt / pip 源，安装 git-lfs、蓝牙、中文字体、SSH 等；
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`，`LANG=zh_CN.UTF-8`；
- 配置 SSH（端口 2223，root 密码 `robot`）、Starship 提示符；
- 工作目录 `/home/robot/ros2_workspace`，进入容器自动 `cd` 到该目录。

## 一键部署（干净机器上的标准流程）

```bash
# 1. 克隆仓库
git clone --recurse-submodules <repo-url> /home/robot/easefuture/ros2_workspace
cd /home/robot/easefuture/ros2_workspace

# 2. 一键起环境（首次会自动构建镜像，耐心等待；之后秒起）
./build_docker.sh up

# 3. 进入容器开发
./build_docker.sh shell
# 或 SSH / VS Code Remote 连接： ssh root@localhost -p 2223  (密码: robot)
```

`./build_docker.sh up` 会在镜像不存在时自动构建、存在时直接复用，再启动容器，无需手动分步 build。

## 跨机器快速迁移（推荐）

每次都重新构建镜像很慢。把构建好的镜像推到镜像仓库，新机器直接拉取即可：

```bash
# A 机：推送镜像（设置你的镜像仓库地址）
REGISTRY=ccr.ccs.tencentyun.com/yourns ./build_docker.sh push

# B 机：拉取后一键起
REGISTRY=ccr.ccs.tencentyun.com/yourns ./build_docker.sh pull
./build_docker.sh up
```

迁移只需带上：① 这个 git 仓库（代码）+ ② 镜像（从仓库 pull）。两者齐了就能跑。

## build_docker.sh 命令一览

| 命令               | 说明                                    |
| ------------------ | --------------------------------------- |
| `up`               | 一键部署：构建（首次）+ 启动容器        |
| `rebuild`          | 强制重建镜像并重启                      |
| `shell`            | 进入容器                                |
| `logs`             | 查看日志                                |
| `down` / `restart` | 停止 / 重启                             |
| `build`            | 仅构建镜像                              |
| `clean`            | 清理容器与镜像                          |
| `push` / `pull`    | 与镜像仓库同步（迁移用，需 `REGISTRY`） |

可用环境变量覆盖：`IMAGE_NAME`、`COMPOSE_FILE`、`BASE_IMAGE`、`REGISTRY`。

## ROS2 学习工作空间

进入容器后：

```bash
# 构建工作空间
colcon build --symlink-install
source install/setup.bash

# 列出可运行的节点
ros2 pkg executables
```

`src/` 下的包（`family_foundation`、`family_public`）推荐用 Git submodule 管理，详见 `src/README.md`。

## 常见命令

```bash
docker logs -f ros2_dev
docker exec -it ros2_dev bash
docker compose -f docker/docker-compose.ros2.yml down
```
