#!/bin/bash
# .claude/hooks/block-dangerous.sh
#
# 危险命令拦截 Hook (PreToolUse, matcher: Bash)
# 拦截可能破坏项目/系统/机器人的危险命令
#
# 防护层级:
#   L1: 系统级破坏  (rm -rf /, mkfs, fork bomb...)
#   L2: Docker 环境破坏 (删除容器/镜像/prune)
#   L3: Git 仓库破坏  (force push, hard reset, clean)
#   L4: 机器人运行安全 (kill -9, reboot, shutdown, systemctl stop)
#   L5: 项目文件破坏  (rm -rf build/devel, 覆盖关键配置)

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
echo "SECURITY: Checking command: $COMMAND" >&2

# ── L1: 系统级破坏模式 ──
L1_PATTERNS=(
    "rm -rf /"                   # 删除根目录
    "rm -rf ~"                   # 删除用户目录
    "rm -rf \$HOME"              # 删除用户目录(变量形式)
    "rm -rf /var/robot"          # 删除机器人相关目录
    "> /dev/sd"                  # 覆写磁盘
    "mkfs."                      # 格式化文件系统
    ":(){:|:&};:"                # Fork bomb
    "chmod -R 777 /"             # 全局权限开放
    "curl.*\| sh"                # 远程脚本直接管道执行
    "curl.*\| bash"              # 远程脚本直接管道执行
    "wget.*\| sh"                # 同上 wget 版本
    "wget.*\| bash"
    "curl.*\| sudo.*sh"          # sudo + 管道 更危险
    "wget.*\| sudo.*bash"
)

# ── L2: Docker 环境破坏 ──
L2_PATTERNS=(
    "docker rm test_docker"            # 删除开发容器
    "docker rm massage_robot_apps"     # 删除测试容器
    "docker rmi"                       # 删除镜像
    "docker system prune"              # 清理全部未使用资源
    "docker volume prune"              # 清理数据卷
    "docker container prune"           # 清理所有停止容器
    "docker image prune"               # 清理未使用镜像
    "docker builder prune"             # 清理构建缓存
    "docker stop test_docker"          # 停止开发容器
    "docker stop massage_robot_apps"   # 停止测试容器
    "docker kill test_docker"          # 强杀开发容器
    "docker kill massage_robot_apps"   # 强杀测试容器
)

# ── L3: Git 仓库破坏 ──
L3_PATTERNS=(
    "git push --force"                # 强制推送 (所有分支)
    "git push -f"                     # 强制推送 (缩写)
    "git reset --hard"                # 硬重置 (丢弃所有本地修改)
    "git clean -fdx"                  # 删除所有未跟踪文件
    "git clean -fd"                   # 删除未跟踪文件和目录
    "git checkout -- ."              # 丢弃所有未暂存修改
    "git branch -D"                   # 强制删除分支
    "git stash drop"                  # 删除 stash
    "git stash clear"                 # 清空所有 stash
    "git submodule deinit"            # 反初始化子模块
)

# ── L4: 机器人运行安全 ──
L4_PATTERNS=(
    "shutdown"                        # 关机 (可能影响机器人)
    "reboot"                          # 重启
    "poweroff"                        # 断电
    "systemctl stop"                  # 停止系统服务
    "systemctl disable"               # 禁用系统服务
    "kill -9"                         # 强杀进程
    "pkill -9"                        # 强杀进程组
    "killall -9"                      # 按名强杀
    "rosnode kill"                    # 杀死 ROS 节点 (可能影响运行中的机器人)
    "rostopic pub.*force"             # 直接发布力控指令 (绕过安全校验)
    "rosparam set.*max_force"         # 修改力控上限参数
)

# ── L5: 项目文件破坏 ──
L5_PATTERNS=(
    "rm -rf*build"                    # 删除构建目录
    "rm -rf*devel"                    # 删除开发目录
    "rm -rf*install"                  # 删除安装目录
    "rm -rf*logs"                     # 删除日志目录
    "rm -rf*.git"                     # 删除 git 仓库
    "rm -rf*src"                      # 删除源码目录
    "> .clang-format"                 # 覆写格式化配置
    "> CMakeLists.txt"                # 覆写构建配置
    "> package.xml"                   # 覆写包配置
    "> .claude/settings.json"         # 覆写 Claude 配置
)

# ── 分级检查 ──
check_patterns() {
    local level="$1"
    shift
    local patterns=("$@")

    for pattern in "${patterns[@]}"; do
        # NOTE: 右侧 ${pattern} 不加引号, 让 * 作为 glob 通配符生效
        if [[ "$COMMAND" == *${pattern}* ]]; then
            echo "BLOCKED [$level]: $pattern" >&2
            cat <<EOF
{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "[$level] 拦截危险命令: 模式 '$pattern' 匹配命令 '$COMMAND'"
    }
}
EOF
            exit 2
        fi
    done
}

check_patterns "L1-系统"   "${L1_PATTERNS[@]}"
check_patterns "L2-Docker" "${L2_PATTERNS[@]}"
check_patterns "L3-Git"    "${L3_PATTERNS[@]}"
check_patterns "L4-机器人" "${L4_PATTERNS[@]}"
check_patterns "L5-项目"   "${L5_PATTERNS[@]}"

# ── 放行 ──
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
