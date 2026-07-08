#!/bin/bash
# .claude/hooks/protect-files.sh
#
# 敏感文件保护 Hook (PreToolUse, matcher: Write|Edit)
# 拦截对关键配置/凭证/模型文件的意外修改
#
# 防护类别:
#   P0-阻断: 凭证/密钥/环境变量 (必须阻止)
#   P1-阻断: Git/CI/构建核心配置 (阻止并要求确认)
#   P2-警告: 机器人安全配置 (允许但需重点关注)
#   P3-提醒: 格式化/代码规范配置 (允许但提醒)

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

FILENAME=$(basename "$FILE_PATH")
EXT="${FILENAME##*.}"
ABSOLUTE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# ── P0: 凭证与密钥文件 (BLOCK) ──
P0_FILENAMES=(
    ".env" ".env.local" ".env.production" ".env.robot"
    "credentials.json" "credentials.yaml" "credentials.yml"
    "secrets.yaml" "secrets.json" "secret.yaml"
    "id_rsa" "id_ed25519" "id_ecdsa" "id_dsa"
    "authorized_keys" "known_hosts"
    "service-account.json" "service-account-key.json"
)

P0_EXTENSIONS=(
    "pem" "key" "p12" "pfx" "jks" "keystore" "cert" "crt"
)

P0_DIR_PATTERNS=(
    ".ssh/"
    ".gnupg/"
    "/etc/ssl/"
)

# ── P1: 项目构建/环境核心配置 (BLOCK) ──
P1_FILENAMES=(
    ".gitignore"                     # 可能排除关键文件
    ".gitmodules"                    # 子模块配置
    "Dockerfile"                     # 容器构建
    "docker-compose.yml" "docker-compose.yaml"
    "CMakeLists.txt"                 # 构建系统
    "Makefile" "GNUmakefile"
    "setup.py" "setup.cfg" "pyproject.toml"
)

P1_PATH_PATTERNS=(
    ".claude/settings.local.json"    # 本地权限/Token (全路径匹配)
    ".git/"                          # Git 仓库元数据
    ".claude/hooks/"                 # Hook 脚本目录
    ".claude/agents/"                # Agent 定义
    ".claude/skills/"                # Skill 定义
    "/opt/ros/"                      # ROS 系统目录
    "/usr/local/"                    # 系统安装目录
    "/etc/"                          # 系统配置目录
)

# ── P2: 机器人安全配置 (WARN) ──
P2_FILENAMES=(
    ".claude/settings.json"          # 项目 Claude 共享配置
    "package.xml"                    # ROS 包定义
    ".clang-format"                  # 格式化标准
    "ros_lib.yaml"                   # ROS 依赖锁定
)

P2_EXTENSIONS=(
    "launch"                         # ROS launch 文件
    "yaml" "yml"                     # 配置文件 (含力控参数)
    "xml"                            # 可能含 URDF/xacro
    "world"                          # Gazebo 世界文件
    "rviz"                           # RViz 配置
)

P2_DIR_PATTERNS=(
    "config/"                        # 配置目录
    "cfg/"                           # 动态参数配置
    "launch/"                        # Launch 文件目录
    "demo_data/"                     # 演示数据
    "test/data/"                     # 测试数据
)

# ── P3: 模型/算法文件 (提醒) ──
P3_EXTENSIONS=(
    "onnx" "engine" "trt" "bin"      # 推理模型
    "pt" "pth" "weights"             # PyTorch 模型
    "pb" "ckpt"                      # TensorFlow 模型
    "xml"                             # OpenVINO 模型描述
)

P3_DIR_PATTERNS=(
    "sdk/"                           # SDK 目录
    "model/" "models/"               # 模型目录
)

# ── 检查函数 ──
block() {
    local level="$1" reason="$2"
    cat <<EOF
{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "[${level}] ${reason}: ${FILENAME}"
    }
}
EOF
    exit 2
}

warn() {
    local level="$1" reason="$2"
    echo "[${level}] WARNING: ${reason}: ${FILE_PATH}" >&2
    # P2/P3 不阻断，但记录警告信息
}

# ── P0 检查: 凭证文件 ──
for name in "${P0_FILENAMES[@]}"; do
    if [[ "$FILENAME" == "$name" ]]; then
        block "P0-凭证" "禁止修改凭证/密钥文件"
    fi
done

for ext in "${P0_EXTENSIONS[@]}"; do
    if [[ "${FILENAME##*.}" == "$ext" ]]; then
        block "P0-凭证" "禁止修改密钥文件 (*.${ext})"
    fi
done

for dir in "${P0_DIR_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$dir"* ]]; then
        block "P0-凭证" "禁止修改安全目录中的文件 (${dir})"
    fi
done

# ── P1 检查: 核心配置 ──

# 文件名匹配
for name in "${P1_FILENAMES[@]}"; do
    if [[ "$FILENAME" == "$name" ]]; then
        block "P1-核心配置" "禁止直接修改核心配置文件，请用 git 或手动确认"
    fi
done

# 全路径模式匹配 (处理带子目录的文件名如 .claude/settings.local.json)
for pattern in "${P1_PATH_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"${pattern}"* ]]; then
        block "P1-核心配置" "禁止修改受保护目录/文件 (${pattern})"
    fi
done

# P1 额外检查: 全局 Claude 配置 (仅拦截 HOME 下的 ~/.claude/settings.json，放行项目内配置)
if [[ "$ABSOLUTE_PATH" == "$HOME/.claude/settings.json" ]]; then
    block "P1-核心配置" "禁止修改全局 Claude 配置 (~/.claude/settings.json)"
fi

# ── P2 检查: 安全配置 (警告但允许) ──
for name in "${P2_FILENAMES[@]}"; do
    if [[ "$FILENAME" == "$name" ]]; then
        warn "P2-安全配置" "正在修改机器人相关配置文件，请确认安全参数未变更"
    fi
done

for ext in "${P2_EXTENSIONS[@]}"; do
    if [[ "$EXT" == "$ext" ]]; then
        # 只 warn 特定目录下的文件，避免对非项目文件误报
        if [[ "$FILE_PATH" == *"/src/"* ]] || [[ "$FILE_PATH" == *"/config/"* ]] || \
           [[ "$FILE_PATH" == *"/launch/"* ]] || [[ "$FILE_PATH" == *"/demo_data/"* ]]; then
            warn "P2-安全配置" "正在修改 ${ext} 配置文件，请审查力控/安全参数"
        fi
    fi
done

for dir in "${P2_DIR_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"/${dir}"* ]]; then
        warn "P2-安全配置" "正在修改配置目录中的文件 (${dir})"
        break
    fi
done

# ── P3 检查: 模型文件 (提醒) ──
for ext in "${P3_EXTENSIONS[@]}"; do
    if [[ "$EXT" == "$ext" ]]; then
        warn "P3-模型文件" "正在修改推理模型文件 (*.${ext})，修改后需重新验证精度"
    fi
done

for dir in "${P3_DIR_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"/${dir}"* ]]; then
        warn "P3-模型文件" "正在修改模型目录中的文件 (${dir})"
        break
    fi
done

# ── 放行 ──
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
