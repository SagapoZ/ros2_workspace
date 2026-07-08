#!/usr/bin/env bash
# ROS2 工作区编译 / 测试脚本
#
# 执行 colcon build / colcon test，自动判断运行环境：
#   - 已在容器内（如 VSCode 远程到容器开发）：直接本地编译；
#   - 在宿主机：通过 docker exec 进 ros2-humble-dev 容器编译（容器需已启动）。
#
# 常用:
#     ./make_project.sh                 # 编译全部包
#     ./make_project.sh public_msgs     # 只编译指定包（及其依赖）
#     ./make_project.sh test            # 编译后运行测试
#     ./make_project.sh clean           # 清理 build/install/log

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT_DIR"

# —— 配置（与 docker-compose.ros2.yml 保持一致）——
CONTAINER_NAME="${CONTAINER_NAME:-ros2-humble-dev}"
ROS_DISTRO="${ROS_DISTRO:-humble}"
# 容器内工作区路径（compose 的 working_dir）
WS_DIR="${WS_DIR:-/home/robot/MoxibustionRobotGroup/ros2_workspace}"

# 判断当前是否已在容器内运行（VSCode 远程到容器开发的场景）
in_container() {
  [[ -f /.dockerenv ]] || grep -qaE '(docker|kubepods|containerd)' /proc/1/cgroup 2>/dev/null
}

# 宿主机模式下，确认目标容器已启动
require_container() {
  if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "!!! 容器 ${CONTAINER_NAME} 未运行，请先执行: ./build_docker.sh up" >&2
    exit 1
  fi
}

# 在工作区执行一段命令（自动 source ROS 环境）：
#   容器内直接本地执行；宿主机则转发到容器内执行。
run_ws() {
  local inner="source /opt/ros/${ROS_DISTRO}/setup.bash && cd ${WS_DIR} && $1"
  if in_container; then
    bash -lc "${inner}"
  else
    require_container
    docker exec -i "${CONTAINER_NAME}" bash -lc "${inner}"
  fi
}

# 把 colcon 的包参数拼成 --packages-select 形式（无包名则编译全部）
packages_arg() {
  if [[ "$#" -gt 0 ]]; then
    echo "--packages-select $*"
  fi
}

# 运行位置描述，用于日志
if in_container; then WHERE="本地（容器内）"; else WHERE="容器 ${CONTAINER_NAME}"; fi

CMD="${1:-build}"
case "$CMD" in
  build)
    PKGS=$(packages_arg "${@:2}")
    echo ">>> 在 ${WHERE} 编译 ${PKGS:-全部包} ..."
    run_ws "colcon build --symlink-install ${PKGS}"
    echo ">>> 编译完成。source 环境: source ${WS_DIR}/install/setup.bash"
    ;;

  test)
    PKGS=$(packages_arg "${@:2}")
    echo ">>> 在 ${WHERE} 编译并测试 ${PKGS:-全部包} ..."
    run_ws "colcon build --symlink-install ${PKGS}"
    run_ws "colcon test ${PKGS} && colcon test-result --verbose"
    ;;

  clean)
    echo ">>> 在 ${WHERE} 清理 build/ install/ log/ ..."
    run_ws "rm -rf build install log"
    echo ">>> 完成。"
    ;;

  *)
    cat <<EOF
ROS2 工作区编译 / 测试脚本

用法: ./make_project.sh <命令> [包名...]

  build [包名...]   编译全部或指定包（默认命令）   <- 常用
  test  [包名...]   编译后运行测试
  clean             清理 build/install/log

示例:
  ./make_project.sh                  编译全部
  ./make_project.sh public_msgs      只编译 public_msgs
  ./make_project.sh test public_msgs 编译并测试 public_msgs

环境变量:
  CONTAINER_NAME  容器名（默认 ${CONTAINER_NAME}）
  ROS_DISTRO      ROS2 版本（默认 ${ROS_DISTRO}）
  WS_DIR          容器内工作区路径（默认 ${WS_DIR}）
EOF
    exit 1
    ;;
esac
