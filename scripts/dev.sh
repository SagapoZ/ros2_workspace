#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

CMD="${1:-help}"
IMAGE_NAME="${IMAGE_NAME:-ros2-dev:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-ros2_dev}"
BASE_IMAGE="${BASE_IMAGE:-osrf/ros:humble-desktop-full-jammy}"
COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
COMPOSE_ARGS=(-f "${COMPOSE_FILE}")

clean_state() {
  echo ">>> Cleaning containers/images for ${CONTAINER_NAME} (${IMAGE_NAME})..."
  docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans >/dev/null 2>&1 || true
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker image rm -f "${IMAGE_NAME}" >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
}

case "$CMD" in
  build)
    clean_state
    echo ">>> Building ${IMAGE_NAME} from docker/Dockerfile..."
    docker build \
      --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
      -t "${IMAGE_NAME}" \
      -f docker/Dockerfile .
    ;;
  up)
    echo ">>> Launching ${CONTAINER_NAME} with docker compose..."
    docker compose "${COMPOSE_ARGS[@]}" up -d
    ;;
  down|stop)
    echo ">>> Stopping docker compose stack..."
    docker compose "${COMPOSE_ARGS[@]}" down
    ;;
  restart)
    "$0" down
    "$0" up
    ;;
  shell|exec)
    echo ">>> Attaching interactive shell to ${CONTAINER_NAME}..."
    docker exec -it "${CONTAINER_NAME}" bash
    ;;
  logs)
    docker logs -f "${CONTAINER_NAME}"
    ;;
  clean)
    clean_state
    ;;
  *)
    echo "Usage: $0 {build|up|down|restart|shell|logs|clean}"
    exit 1
    ;;
esac
