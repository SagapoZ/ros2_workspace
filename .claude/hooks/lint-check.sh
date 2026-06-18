#!/bin/bash
# .claude/hooks/lint-check.sh
#
# 静态检查 Hook (PostToolUse, matcher: Write|Edit)
# 在文件写入后自动进行语法/格式/安全模式检查
#
# 检查项 (按文件类型):
#   C++:    clang-format 格式检查 + 7 类不安全模式扫描 (python3)
#   Python: py_compile 语法检查 + 危险模式扫描
#   YAML:   语法校验
#   Shell:  语法检查 + 危险模式
#   CMake:  if/endif 匹配 + catkin 依赖检查

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo '{}'
    exit 0
fi

EXT="${FILE_PATH##*.}"
FILENAME=$(basename "$FILE_PATH")
MAX_PER_RULE=5

warn() { echo "  ⚠️  $1" >&2; }
header() { echo "[lint] $1" >&2; }

# ── C++ 检查 ──
check_cpp() {
    header "C++: ${FILENAME}"

    # 1. clang-format 格式检查
    if command -v clang-format &>/dev/null; then
        local cfg_dir && cfg_dir=$(dirname "$FILE_PATH")
        while [ "$cfg_dir" != "/" ]; do
            [ -f "$cfg_dir/.clang-format" ] && break
            cfg_dir=$(dirname "$cfg_dir")
        done

        local style="--style=file"
        [ "$cfg_dir" = "/" ] && style="--style={BasedOnStyle: Google, IndentWidth: 4, BreakBeforeBraces: Allman, ColumnLimit: 100}"

        if ! clang-format --dry-run --Werror "$style" "$FILE_PATH" 2>/dev/null; then
            warn "格式不符合 clang-format 规范 (Allman大括号/4空格缩进/100列宽)"
        fi
    fi

    # 2. Python 模式扫描
    if command -v python3 &>/dev/null; then
        python3 - "$FILE_PATH" "$MAX_PER_RULE" "$FILENAME" <<'PYEOF'
import re, sys
fpath, limit, fname = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(fpath) as f:
    lines = f.readlines()

counts = {}
def report(rule, sev, msg, lineno=None):
    s = f"  {sev}:{rule} L{lineno}: {msg}" if lineno else f"  {sev}:{rule}: {msg}"
    print(s)

# ── 🔴 阻断性规则 ──

# R1: 不安全C函数
r = "unsafe-c-func"
for i, line in enumerate(lines, 1):
    for func in ['sprintf(', 'strcpy(', 'strcat(', 'gets(']:
        if func in line and 'snprintf' not in line and 'strncpy' not in line:
            before = line.split(func)[0].strip()
            if not before.startswith('//'):
                counts[r] = counts.get(r, 0) + 1
                if counts[r] <= limit:
                    report(r, "🔴", f"禁止使用 {func[:-1]}, 改用 snprintf/strncpy/std::string", i)

# R2: ROS_LOG 在 RT 线程 (仅 controller/safety 相关文件)
r = "rt-ros-log"
rt_kw = ['controller', 'control', 'safety', 'rt_', 'realtime']
if any(kw in fname.lower() for kw in rt_kw):
    for i, line in enumerate(lines, 1):
        if re.search(r'ROS_(INFO|WARN|ERROR|DEBUG)\s*\(', line):
            before = line.split('ROS_')[0].strip()
            if not before.startswith('//'):
                counts[r] = counts.get(r, 0) + 1
                if counts[r] <= limit:
                    report(r, "🔴", "RT线程中禁止 ROS_LOG, 改用 RT_LOG_INFO() 或模块宏 MASSAGE_INFO/SAFETY_RT_INFO/EVTHW_INFO", i)

# R3: Lambda [&] 引用捕获
r = "lambda-ref-capture"
for i, line in enumerate(lines, 1):
    stripped = line.split('//')[0] if '//' in line else line
    if re.search(r'\[\s*&\s*\]', stripped):
        counts[r] = counts.get(r, 0) + 1
        if counts[r] <= limit:
            report(r, "🔴", "lambda [&] 可能导致悬空引用, 异步场景用 [=] 或显式捕获", i)

# R4: system()/popen() 调用
r = "dangerous-exec"
for i, line in enumerate(lines, 1):
    if re.search(r'\b(system|popen)\s*\(', line):
        before = line.split('system')[0].split('popen')[0].strip()
        if not before.startswith('//'):
            counts[r] = counts.get(r, 0) + 1
            if counts[r] <= limit:
                report(r, "🔴", "system()/popen() 命令注入风险, 用白名单验证或 fork+exec", i)

# R5: 硬编码凭证
r = "hardcoded-secret"
for i, line in enumerate(lines, 1):
    if re.search(r'(AUTH_TOKEN|API_KEY|password|secret)\s*=\s*["\'][^$]', line):
        before = line.split('=')[0].strip()
        if not before.startswith('//'):
            counts[r] = counts.get(r, 0) + 1
            if counts[r] <= limit:
                report(r, "🔴", "禁止硬编码凭证/Token, 从环境变量读取", i)

# ── 🟡 重要规则 ──

# R6: 基类虚析构缺失
r = "non-virtual-dtor"
for i, line in enumerate(lines, 1):
    m = re.match(r'\s*class\s+(\w+)', line)
    if m:
        cn = m.group(1)
        j, has_vf, dtor_v = i, False, False
        while j < len(lines):
            l = lines[j]
            if l.strip() == '};': break
            if 'virtual' in l and '~' not in l:
                has_vf = True
            if '~' in l:
                dtor_v = 'virtual' in l
                if has_vf and not dtor_v:
                    counts[r] = counts.get(r, 0) + 1
                    if counts[r] <= limit:
                        report(r, "🟡", f"类 {cn} 有虚函数但析构非virtual, 资源泄漏风险", i)
                break
            j += 1

# R7: Eigen::MatrixXd 动态分配 (RT提示)
r = "eigen-dynamic"
for i, line in enumerate(lines, 1):
    if re.search(r'Eigen::MatrixXd\s+\w+', line):
        if not line.strip().startswith('//'):
            counts[r] = counts.get(r, 0) + 1
            if counts[r] <= limit:
                report(r, "🟡", "Eigen::MatrixXd 动态分配, RT线程用固定大小 Matrix<double,R,C>", i)

# ── 汇总 ──
total = sum(min(v, limit) for v in counts.values())
if total == 0:
    print("  ✅ 未检测到常见问题")
else:
    print(f"  📊 共 {total} 条问题 ({len(counts)} 类), 每类最多 {limit} 条")
PYEOF
    fi
}

# ── Python 检查 ──
check_python() {
    header "Python: ${FILENAME}"

    if python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
        echo "  ✅ 语法正确" >&2
    else
        warn "Python 语法错误"
    fi

    python3 - "$FILE_PATH" "$MAX_PER_RULE" <<'PYEOF'
import re, sys
fpath, limit = sys.argv[1], int(sys.argv[2])
with open(fpath) as f:
    lines = f.readlines()
c = 0
for i, line in enumerate(lines, 1):
    if re.search(r'(AUTH_TOKEN|API_KEY|password|secret)\s*=\s*["\'][^$]', line):
        if not line.strip().startswith('#'):
            c += 1;
            if c <= limit: print(f"  🔴 L{i}: 禁止硬编码凭证/Token")
    if re.search(r'\bos\.system\s*\(', line):
        if not line.strip().startswith('#'):
            c += 1
            if c <= limit: print(f"  🔴 L{i}: os.system() 命令注入风险, 改用 subprocess.run")
if c == 0: print("  ✅ 未检测到常见问题")
PYEOF
}

# ── YAML 检查 ──
check_yaml() {
    header "YAML: ${FILENAME}"
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$FILE_PATH'))" 2>/dev/null; then
            echo "  ✅ YAML 语法正确" >&2
        else
            warn "YAML 语法错误"
        fi
    fi
}

# ── Shell 检查 ──
check_shell() {
    header "Shell: ${FILENAME}"
    bash -n "$FILE_PATH" 2>/dev/null && echo "  ✅ Shell 语法正确" >&2 || warn "Shell 语法错误"
    grep -q 'rm -rf /' "$FILE_PATH" 2>/dev/null && warn "检测到危险的 rm -rf /"
}

# ── CMake 检查 ──
check_cmake() {
    header "CMake: ${FILENAME}"
    local ifcount=$(grep -cE '^\s*(if|elseif)\s*\(' "$FILE_PATH" 2>/dev/null || echo 0)
    local endifcount=$(grep -cE '^\s*endif\s*\(' "$FILE_PATH" 2>/dev/null || echo 0)
    [ "$ifcount" != "$endifcount" ] && warn "if/endif 数量不匹配 (if:${ifcount} endif:${endifcount})"
    if grep -q 'catkin_' "$FILE_PATH" 2>/dev/null && ! grep -q 'find_package(catkin' "$FILE_PATH" 2>/dev/null; then
        warn "使用了 catkin_ 宏但未 find_package(catkin ...)"
    fi
    echo "  ✅ CMake 基本检查完成" >&2
}

# ── 主分发 ──
case "$EXT" in
    cpp|h|hpp|cc|cxx|c)   check_cpp   ;;
    py)                    check_python ;;
    yaml|yml)              check_yaml   ;;
    sh|bash)               check_shell  ;;
    *)
        if [ "$FILENAME" = "CMakeLists.txt" ]; then
            check_cmake
        elif head -1 "$FILE_PATH" 2>/dev/null | grep -q '^#!/.*bash'; then
            check_shell
        else
            echo '{}'; exit 0
        fi
        ;;
esac

echo '{"hookSpecificOutput":{"additionalContext":"lint-check 完成"}}'
exit 0
