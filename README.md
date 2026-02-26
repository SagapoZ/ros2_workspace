# ros2_workspace

统一管理机器人软件的 ROS 2 开发环境、容器镜像、脚本以及三大子项目 (`robot_application` / `robot_public` / `robot_foundation`) 的壳工程。

## 目录结构

```
ros2_workspace
├── docker/
│   ├── Dockerfile                  # ROS 2 Humble 开发镜像
│   └── docker-compose.yml          # Linux/WSL 宿主使用
├── docker/envs/                    # compose 使用的可选 env 文件
├── docs/
│   └── windows_wsl_setup.md        # Windows / WSL 快速入门
├── scripts/
│   ├── dev.sh                      # Linux/macOS 通用脚本
│   ├── dev.ps1                     # Windows PowerShell 脚本
│   └── install_docker_ubuntu.sh    # Ubuntu Docker 一键安装
├── src/
│   ├── robot_application/          # 推荐以 Git submodule 管理
│   ├── robot_public/
│   └── robot_foundation/
└── README.md
```

仓库在宿主机与容器中均挂载至 `/home/robot/ros2_workspace`，方便文档与路径统一。

## 镜像简介（docker/Dockerfile）

- 基于 `ros:humble-desktop`，默认用户 `root`；
- 使用清华 apt 源，安装 git、git-lfs、colcon、rosdep、MoveIt、Gazebo、音视频依赖等；
- 配置 SSH（端口 2223）、中文字体、GPU & GUI 运行所需的库；
- 工作目录 `/home/robot/ros2_workspace`，进入容器自动 `cd` 到该目录。

构建镜像：

```bash
./scripts/dev.sh build
```

## Compose 启动方式（Linux / WSL）

- `host` 网络、`privileged`、`cap_add` 适用于需要访问 `/dev`、DBus、systemd 等硬件资源的场景；
- 映射 SSH 端口：`${SSH_PORT_HOST:-2223}`；
- 通过 `env_file` 引入 `docker/envs/*.env`。

启动：

```bash
./scripts/dev.sh up
# 或自定义 COMPOSE_FILE
COMPOSE_FILE=docker/docker-compose.yml docker compose up -d
```

Windows 端如通过 **WSL2** 运行 Docker Engine，仅需在 WSL 中执行相同命令或使用 `.\scripts\dev.ps1`，该脚本同样指向 `docker/docker-compose.yml`。

## 一键脚本

| 脚本                | 说明 |
|--------------------|------|
| `scripts/dev.sh`   | `build`（自动清理旧镜像/容器，默认基于 `osrf/ros:humble-desktop-full-jammy`，可自定义 `BASE_IMAGE`） / `up` / `down` / `restart` / `shell` / `logs` / `clean` |
| `scripts/dev.ps1`  | Windows PowerShell 包装器，通过 WSL 调用 `dev.sh` |
| `scripts/install_docker_ubuntu.sh` | 安装 Docker Engine + compose 插件 |

示例：

```bash
./scripts/dev.sh shell     # 进入容器
./scripts/dev.sh logs      # 查看容器日志
```

## 开发流程

1. **克隆仓库**
   ```bash
   git clone --recurse-submodules <repo-url> /home/robot/ros2_workspace
   ```
2. **构建镜像**：`./scripts/dev.sh build`
   - 脚本会先执行 `clean`，自动移除旧的 `ros2_dev` 容器与镜像；
   - 默认基镜像为 `osrf/ros:humble-desktop-full-jammy`；如需使用其他镜像，可设置 `BASE_IMAGE=<your-image> ./scripts/dev.sh build`，例如 `BASE_IMAGE=mirror.ccs.tencentyun.com/osrf/ros:humble-desktop-full-jammy`.
3. **启动容器**：`./scripts/dev.sh up`
4. **远程开发**：SSH / VS Code Remote 连接 `root@localhost -p 2223`，密码 `robot`。
5. **管理子项目**：`src` 下各目录推荐使用 Git submodule。

容器设置 `restart: unless-stopped`，配合 Docker 服务自启，即可实现主机重启后自动拉起。

## Windows / WSL2 流程

详见 `docs/windows_wsl_setup.md`，涵盖：

- 启用 WSL2、确认 WSLg（或配置 X Server）；
- 在 WSL 内安装 Docker Engine + compose 插件；
- 克隆仓库、构建镜像、启动容器；
- 通过 SSH / VS Code Remote 进入容器并使用 RViz、Gazebo 等 GUI。

## 常见命令

```bash
docker logs -f ros2_dev
docker exec -it ros2_dev bash
docker compose -f docker/docker-compose.yml down
```
