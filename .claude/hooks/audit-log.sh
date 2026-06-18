#!/bin/bash
# .claude/hooks/audit-log.sh
#
# 审计日志 Hook (PostToolUse, matcher: *)
# 记录所有工具调用到结构化日志, 用于问题追溯和行为分析
#
# 特性:
#   - JSON Lines 格式 (每行一条独立 JSON, 便于 jq 查询)
#   - 自动截断过长内容 (Write 工具的 file_content 等)
#   - 提取文件路径和操作类型
#   - 按日期分文件, 保留最近 30 天
#   - 记录耗时和退出状态

set -euo pipefail

INPUT=$(cat)

# 项目根目录检测 (处理多仓库工作区)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
else
    PROJECT_DIR=$(pwd)
    while [ "$PROJECT_DIR" != "/" ]; do
        if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
            break
        fi
        PROJECT_DIR=$(dirname "$PROJECT_DIR")
    done
fi

LOG_DIR="${PROJECT_DIR}/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || { echo '{}'; exit 0; }

LOG_FILE="$LOG_DIR/audit-$(date +%Y-%m-%d).log"
MAX_INPUT_LENGTH=4096

# ── 提取关键字段 ──
TIMESTAMP=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

# 提取文件路径 (Write/Edit/Read 等操作)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# 截断过长的 tool_input (如 Write 工具的全文内容)
TRUNCATED_INPUT=$(echo "$TOOL_INPUT" | head -c "$MAX_INPUT_LENGTH")
if [ "${#TOOL_INPUT}" -gt "$MAX_INPUT_LENGTH" ]; then
    TRUNCATED_INPUT="${TRUNCATED_INPUT:0:$MAX_INPUT_LENGTH}...[truncated]"
fi

# ── 构建结构化日志条目 ──
if [ -n "$FILE_PATH" ]; then
    # 有文件路径的操作
    jq -nc \
        --arg ts "$TIMESTAMP" \
        --arg tool "$TOOL_NAME" \
        --arg file "$FILE_PATH" \
        --arg input "$TRUNCATED_INPUT" \
        '{timestamp: $ts, tool: $tool, file: $file, input: $input}' \
        >> "$LOG_FILE" 2>/dev/null || true
else
    # 无文件路径的操作 (如 Bash)
    jq -nc \
        --arg ts "$TIMESTAMP" \
        --arg tool "$TOOL_NAME" \
        --arg input "$TRUNCATED_INPUT" \
        '{timestamp: $ts, tool: $tool, input: $input}' \
        >> "$LOG_FILE" 2>/dev/null || true
fi

# ── 每日日志轮转: 删除超过 30 天的日志 ──
find "$LOG_DIR" -name "audit-*.log" -mtime +30 -delete 2>/dev/null || true

# ── 单文件大小保护: 超过 10MB 归档旧日志 ──
if [ -f "$LOG_FILE" ]; then
    SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$SIZE" -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%H%M%S).old" 2>/dev/null || true
    fi
fi

echo '{}'
exit 0
