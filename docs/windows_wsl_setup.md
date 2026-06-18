# Windows/WSL2 ROS2 开发流程

本指南介绍如何在 **Windows 11 + WSL2 (Ubuntu)** 环境中，直接在 WSL 内安装 Docker Engine 并运行本仓库提供的 ROS 2 Humble 容器，保证 RViz / Gazebo 等 GUI 正常显示。

## 1. 启用 WSL2 与 WSLg

```powershell
wsl --install
wsl --set-default-version 2
wsl --list --online
wsl --install -d Ubuntu
```

首次启动 Ubuntu 时创建用户（建议 `robot`），再更新系统：

```bash
sudo apt update && sudo apt upgrade -y
```

Windows 11 默认启用 **WSLg**（Wayland/Weston），可直接显示 WSL 中的 Linux GUI。如果禁用了 WSLg 或使用 Win10，请安装 X Server（VcXsrv / X410）并在 WSL 中配置 `DISPLAY`。

## 2. WSL 内安装 Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

重新打开 WSL 终端，使 `docker` 命令无需 `sudo`。验证：

```bash
docker version
docker compose version
```

若使用 systemd（`/etc/wsl.conf` 中设置 `systemd=true`），可执行：

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

否则可在 Windows 计划任务里添加 `wsl -d Ubuntu -u root service docker start` 实现开机自启。

## 3. 拉取仓库与依赖

```bash
mkdir -p /home/robot
cd /home/robot
git clone --recurse-submodules <your-shell-repo-url> ros2_workspace
cd ros2_workspace
```

路径需保持为 `/home/robot/ros2_workspace`，与 compose 里的挂载一致。

## 4. 构建镜像

```bash
./build_docker.sh build
```

若构建失败需要重试，脚本会自动清理旧镜像/容器，你也可以单独执行 `./build_docker.sh clean`。默认基镜像是 `osrf/ros:humble-desktop-full-jammy`；如果需要换源或镜像，执行 `BASE_IMAGE=<可访问镜像> ./build_docker.sh build`（例如 `BASE_IMAGE=mirror.ccs.tencentyun.com/osrf/ros:humble-desktop-full-jammy`）。

## 5. 启动容器

```bash
./build_docker.sh up
# 等价：docker compose -f docker/docker-compose.yml up -d
```

容器使用 `restart: unless-stopped`，当 WSL 中的 Docker daemon 启动时会自动恢复上次的运行状态。

## 6. VS Code / SSH 调试

1. 安装 VS Code + Remote Development；
2. Windows 端执行 `ssh root@localhost -p 2223`（密码 `robot`）确认可登录；
3. 在 VS Code 中新增 SSH Target：`root@localhost -p 2223`，即可在容器里开发；
4. 容器默认路径 `/home/robot/ros2_workspace`，可直接运行 `colcon build`、`ros2 launch`。

## 7. GUI（RViz / Gazebo）

- **WSLg 场景（Win11 默认）**：无需额外配置，容器继承 `DISPLAY` 与 `/tmp/.X11-unix` 挂载后，直接运行 `rviz2`、`gazebo` 等命令即可在 Windows 桌面显示。
- **无 WSLg 的场景**：安装 X Server，并在 WSL shell 中执行 `export DISPLAY=$(grep nameserver /etc/resolv.conf | awk '{print $2}'):0.0`。compose 已包含 `DISPLAY` 环境变量和 `/tmp/.X11-unix` 挂载，可直接使用。

## 8. 常用命令

```bash
# 查看日志
docker logs -f ros2_dev

# 进入容器
docker exec -it ros2_dev bash

# 停止容器
docker compose -f docker/docker-compose.yml down
```

在 WSL 中执行 `./build_docker.sh`；若想直接在 Windows PowerShell 中操作，可运行 `.\scripts\dev.ps1 build|up|down`，脚本会自动调用 WSL。无需 Docker Desktop，所有容器与构建流程全部在 WSL 内完成。
