#!/bin/bash
# .claude/hooks/auto-format.sh
#
# 文件自动格式化 Hook (PostToolUse)
# 在 Write/Edit 操作后自动格式化对应文件类型
#
# 支持:
#   C++ (.cpp/.h/.hpp/.cc/.cxx/.c) → clang-format
#   Python (.py)                   → black / autopep8 fallback
#   YAML  (.yaml/.yml)             → 去除行尾空格
#   CMakeLists.txt                 → 去除行尾空格
#   Web   (.js/.ts/.json/.md等)    → prettier (如可用)

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo '{}'
    exit 0
fi

EXT="${FILE_PATH##*.}"
FILENAME=$(basename "$FILE_PATH")

# 向上查找最近的配置文件
find_nearest_config() {
    local config_name="$1"
    local dir
    dir=$(dirname "$FILE_PATH")
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/$config_name" ]; then
            echo "$dir/$config_name"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

format_clang() {
    if ! command -v clang-format &>/dev/null; then
        return 0  # 工具不可用, 静默跳过
    fi

    # 查找最近的 .clang-format, 找不到则用 Google 风格回退
    local clang_config
    clang_config=$(find_nearest_config ".clang-format" || echo "")

    local style_arg="--style=file"
    if [ -z "$clang_config" ]; then
        # 项目默认风格 (Allman大括号 + 4空格 + Google基础)
        style_arg="--style={BasedOnStyle: Google, IndentWidth: 4, BreakBeforeBraces: Allman, ColumnLimit: 100, AccessModifierOffset: -4}"
    fi

    clang-format -i "$style_arg" "$FILE_PATH" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"additionalContext":"已用 clang-format 格式化"}}'
}

format_python() {
    if command -v black &>/dev/null; then
        black --quiet "$FILE_PATH" 2>/dev/null || true
        echo '{"hookSpecificOutput":{"additionalContext":"已用 Black 格式化"}}'
    elif command -v autopep8 &>/dev/null; then
        autopep8 --in-place --aggressive "$FILE_PATH" 2>/dev/null || true
        echo '{"hookSpecificOutput":{"additionalContext":"已用 autopep8 格式化"}}'
    else
        # 无格式化工具, 仅去除行尾空格
        strip_trailing_whitespace
        echo '{"hookSpecificOutput":{"additionalContext":"已去除行尾空格 (black/autopep8 未安装)"}}'
    fi
}

format_yaml() {
    # yamllint 不可用时的轻量处理: 去行尾空格 + 补末尾换行
    strip_trailing_whitespace
    ensure_trailing_newline
    echo '{"hookSpecificOutput":{"additionalContext":"已格式化 YAML (去行尾空格)"}}'
}

format_cmake() {
    if command -v cmake-format &>/dev/null; then
        cmake-format -i "$FILE_PATH" 2>/dev/null || true
        echo '{"hookSpecificOutput":{"additionalContext":"已用 cmake-format 格式化"}}'
    else
        strip_trailing_whitespace
        echo '{"hookSpecificOutput":{"additionalContext":"已格式化 CMake (去行尾空格)"}}'
    fi
}

format_prettier() {
    if command -v npx &>/dev/null; then
        npx prettier --write "$FILE_PATH" 2>/dev/null || true
        echo '{"hookSpecificOutput":{"additionalContext":"已用 Prettier 格式化"}}'
    fi
}

strip_trailing_whitespace() {
    sed -i 's/[[:space:]]*$//' "$FILE_PATH" 2>/dev/null || true
}

ensure_trailing_newline() {
    # 确保文件末尾有且仅有一个换行
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$FILE_PATH" 2>/dev/null || true
    [ -s "$FILE_PATH" ] && [ "$(tail -c1 "$FILE_PATH" | wc -l)" -eq 0 ] && echo "" >> "$FILE_PATH" || true
}

# ---- 主分发逻辑 ----
case "$EXT" in
    cpp|h|hpp|cc|cxx|c)
        format_clang
        ;;
    py)
        format_python
        ;;
    yaml|yml)
        format_yaml
        ;;
    js|jsx|ts|tsx|json|md|css|scss|html)
        format_prettier
        ;;
    *)
        # CMakeLists.txt 无扩展名, 按文件名匹配
        if [ "$FILENAME" = "CMakeLists.txt" ]; then
            format_cmake
        else
            echo '{}'
        fi
        ;;
esac

exit 0
