#!/usr/bin/env bash
# ROS2 开发环境管理脚本（仅 Linux / WSL2）
#
# 一键部署：在一台干净的机器上克隆仓库后，只需
#     ./build_docker.sh up
# 即可完成「构建镜像（首次）+ 启动容器」，随后用
#     ./build_docker.sh shell
# 进入容器开发。
#
# 跨机器迁移更快的方式：在 A 机 `build_docker.sh push`，在 B 机 `build_docker.sh pull && build_docker.sh up`，
# 省去重新构建镜像的时间（需设置 REGISTRY 环境变量）。

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT_DIR"

# —— 配置（与 docker-compose.ros2.yml 保持一致）——
COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.ros2.yml}"
IMAGE_NAME="${IMAGE_NAME:-family_robot_ros2:ros2}"
CONTAINER_NAME="${CONTAINER_NAME:-ros2_dev}"
SSH_PORT="${SSH_PORT:-2223}"
# 推送/拉取镜像用的远程仓库，例如 REGISTRY=ccr.ccs.tencentyun.com/yourns
REGISTRY="${REGISTRY:-}"

COMPOSE=(docker compose -f "${COMPOSE_FILE}")

require_compose_file() {
  if [[ ! -f "${COMPOSE_FILE}" ]]; then
    echo "!!! 找不到 compose 文件: ${COMPOSE_FILE}" >&2
    exit 1
  fi
}

print_access_info() {
  echo ""
  echo ">>> 容器 ${CONTAINER_NAME} 已就绪。"
  echo "    进入容器:  ./build_docker.sh shell"
  echo "    SSH 连接:  ssh root@localhost -p ${SSH_PORT}  (密码: robot)"
  echo "    查看日志:  ./build_docker.sh logs"
}

CMD="${1:-help}"
case "$CMD" in
  build)
    require_compose_file
    echo ">>> 构建镜像 ${IMAGE_NAME} ..."
    "${COMPOSE[@]}" build "${@:2}"
    ;;

  up|deploy)
    # 一键部署：镜像不存在则自动构建，然后启动容器
    require_compose_file
    echo ">>> 启动 ${CONTAINER_NAME}（首次会自动构建镜像，请耐心等待）..."
    "${COMPOSE[@]}" up -d
    print_access_info
    ;;

  rebuild)
    # 强制重新构建镜像并重启容器
    require_compose_file
    echo ">>> 强制重建镜像并重启 ${CONTAINER_NAME} ..."
    "${COMPOSE[@]}" up -d --build
    print_access_info
    ;;

  down|stop)
    require_compose_file
    echo ">>> 停止并移除容器 ..."
    "${COMPOSE[@]}" down
    ;;

  restart)
    "$0" down
    "$0" up
    ;;

  shell|exec)
    echo ">>> 进入 ${CONTAINER_NAME} ..."
    docker exec -it "${CONTAINER_NAME}" bash
    ;;

  logs)
    docker logs -f "${CONTAINER_NAME}"
    ;;

  push)
    [[ -n "${REGISTRY}" ]] || { echo "!!! 请先设置 REGISTRY，例如 REGISTRY=ccr.ccs.tencentyun.com/yourns ./build_docker.sh push" >&2; exit 1; }
    REMOTE="${REGISTRY}/${IMAGE_NAME}"
    echo ">>> 推送镜像到 ${REMOTE} ..."
    docker tag "${IMAGE_NAME}" "${REMOTE}"
    docker push "${REMOTE}"
    ;;

  pull)
    [[ -n "${REGISTRY}" ]] || { echo "!!! 请先设置 REGISTRY，例如 REGISTRY=ccr.ccs.tencentyun.com/yourns ./build_docker.sh pull" >&2; exit 1; }
    REMOTE="${REGISTRY}/${IMAGE_NAME}"
    echo ">>> 从 ${REMOTE} 拉取镜像 ..."
    docker pull "${REMOTE}"
    docker tag "${REMOTE}" "${IMAGE_NAME}"
    echo ">>> 已拉取并打标签为 ${IMAGE_NAME}，可直接 ./build_docker.sh up"
    ;;

  clean)
    require_compose_file
    echo ">>> 清理容器与镜像 ${IMAGE_NAME} ..."
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker image rm -f "${IMAGE_NAME}" >/dev/null 2>&1 || true
    echo ">>> 完成。"
    ;;

  *)
    cat <<EOF
ROS2 开发环境管理脚本（Linux / WSL2）

用法: ./build_docker.sh <命令>

  up        一键部署：构建镜像（首次）+ 启动容器   <- 常用
  rebuild   强制重新构建镜像并重启容器
  shell     进入容器
  logs      查看容器日志
  down      停止并移除容器
  restart   重启容器
  build     仅构建镜像
  clean     清理容器与镜像
  push      推送镜像到 REGISTRY（跨机迁移用）
  pull      从 REGISTRY 拉取镜像（跨机迁移用）

环境变量:
  REGISTRY     远程镜像仓库地址（push/pull 用）
  IMAGE_NAME   镜像名（默认 ${IMAGE_NAME}）
  COMPOSE_FILE compose 文件（默认 ${COMPOSE_FILE}）
EOF
    exit 1
    ;;
esac
