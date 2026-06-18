# Claude Code 项目配置说明

> Family Robot Workspace — 团队共享 Claude Code 配置
> 最后更新: 2026-06-11
> 项目入口文件: [`CLAUDE.md`](../CLAUDE.md) — 自动加载到每次会话

---

## 一、环境变量（必须）

根据操作系统和 Shell 选择对应的配置文件：

| 系统 | Shell | 配置文件 | 生效命令 |
|------|-------|----------|----------|
| Linux | bash | `~/.bashrc` | `source ~/.bashrc` |
| macOS | zsh（默认） | `~/.zshrc` | `source ~/.zshrc` |
| macOS | bash | `~/.bash_profile` | `source ~/.bash_profile` |

在对应配置文件中添加：

```bash
# Claude Code - Anthropic API
export ANTHROPIC_AUTH_TOKEN="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_MODEL="deepseek-v4-pro[1M]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1M]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-pro[1M]"
export ANTHROPIC_SMALL_FAST_MODEL="deepseek-v4-flash[1M]"
export API_TIMEOUT_MS="600000"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
```

> **注意**: `ANTHROPIC_AUTH_TOKEN` 请替换为自己的 API Key，勿将 Key 硬编码在配置文件中或提交到 Git。

---

## 二、配置层级

```
~/.claude/settings.json              ← 全局配置（所有项目通用）
壳工程/.claude/settings.json         ← 项目级配置（通过 symlink 共享给所有子仓库）
壳工程/.claude/settings.local.json   ← 本地覆盖（权限规则等，不提交 Git）
壳工程/.claude/agents/               ← 自定义 Agent 定义
壳工程/.claude/skills/               ← 自定义 Skill 定义
```

优先级：`settings.local.json` > `settings.json`（项目） > `settings.json`（全局）

---

## 三、目录结构

```
family_robot_workspace/
├── CLAUDE.md                        ← 项目入口，指向本 README
│
├── .claude/                         ← 唯一配置源（在此维护所有配置）
│   ├── README.md                    ← 本文件（完整配置说明）
│   ├── settings.json                ← 项目共享设置 + Hooks 配置
│   ├── settings.local.json          ← 本地权限（不提交 Git）
│
├── agents/                          ← 自定义 Agent（7个）
│   ├── build-agent.md               # Docker 编译
│   ├── bug-locator.md               # Bug 定位
│   ├── bug-fixer.md                 # Bug 修复 (自动加载 secure-coding)
│   ├── bug-verify.md                # Bug 验证
│   ├── bug-report.md                # Bug 报告
│   ├── test-runner.md               # 测试执行
│   └── security-reviewer.md         # 安全审查 (P0~P3)
│
├── skills/                          ← 自定义 Skill（2个）
│   ├── code-reviewing/              # C++ ROS1 代码审查
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── common-issues.md     # RT安全/线程/内存/ROS 常见问题
│   │       └── coding-standards.md  # 格式化/命名/规范
│   └── secure-coding/               # 安全编码规范
│       ├── SKILL.md
│       └── references/
│           ├── cpp-memory-safety.md   # Lambda悬空/空指针/缓冲区
│           ├── injection-defense.md   # 命令注入/路径遍历/YAML
│           ├── physical-safety.md     # 力上限/急停/视觉查询
│           └── ros-security.md        # 消息校验/参数安全/topic频率
│
├── hooks/                           ← Hook 脚本（4个）
│   ├── auto-format.sh               # 自动格式化 (PostToolUse)
│   ├── lint-check.sh                # 静态检查 (PostToolUse)
│   ├── block-dangerous.sh           # 危险命令拦截 (PreToolUse)
│   ├── protect-files.sh             # 敏感文件保护 (PreToolUse)
│   └── audit-log.sh                 # 审计日志 (PostToolUse)
│
└── logs/                            ← 审计日志输出（自动生成, .gitignore）
    └── audit-YYYY-MM-DD.log         # JSON Lines 格式

src/
  family_algorithm/.claude   →  ../../.claude   ← 符号链接
  family_foundation/.claude  →  ../../.claude   ← 符号链接
  family_application/.claude →  ../../.claude   ← 符号链接
```

所有子仓库的 `.claude/` 均为壳工程的符号链接，修改壳工程配置即可全局生效。

---

## 四、Hooks 自动化体系

### 触发流程

```
用户操作                     Hooks 响应
────────────────────────────────────────────────
Bash(git push:*)      → PreToolUse  → code-reviewing skill 审查
Bash                  → PreToolUse  → block-dangerous.sh 拦截危险命令
Write|Edit            → PreToolUse  → protect-files.sh 保护敏感文件
Write|Edit            → PostToolUse → auto-format.sh 自动格式化
Write|Edit            → PostToolUse → lint-check.sh 静态检查
* (所有操作)           → PostToolUse → audit-log.sh 审计日志
```

### Hook 详情

| Hook | 时机 | 功能 |
|------|------|------|
| **block-dangerous.sh** | 命令执行前 | 五级拦截: L1系统 / L2-Docker / L3-Git / L4-机器人 / L5-项目 |
| **protect-files.sh** | 文件写入前 | 四级保护: P0凭证密钥(阻止) / P1核心配置(阻止) / P2安全配置(警告) / P3模型文件(提醒) |
| **auto-format.sh** | 文件写入后 | C++ (clang-format) / Python (black→autopep8) / YAML / CMake |
| **lint-check.sh** | 文件写入后 | C++ 7类规则扫描 / Python语法 / YAML语法 / Shell语法 / CMake检查 |
| **audit-log.sh** | 全部操作后 | JSON Lines 结构化日志, 30天轮转, 10MB归档 |

---

## 五、Skills 快速参考

### code-reviewing（代码审查）

触发词: `review`, `审查代码`, `check this PR`, `audit`

审查优先级: 🔴严重 > 🟡主要 > 🔵次要

| 优先级 | 检查项 |
|--------|--------|
| 🔴 严重 | 空指针/数组越界、RT线程堆分配/日志/IO、数据竞争、命令注入 |
| 🟡 主要 | 性能问题(O(n²)/深拷贝)、异常安全、服务调用超时、硬编码 |
| 🔵 次要 | Allman大括号、4空格缩进、命名规范、include顺序 |

### secure-coding（安全编码）

自动加载: bug-fixer 修复涉及硬件控制/用户输入/回调的代码时

| 优先级 | 检查项 |
|--------|--------|
| 阻断性 | Lambda [&] 捕捉、空指针、sprintf溢出、命令注入、力控无上限、急停阻塞 |
| 重要 | 输入验证、ROS消息校验、参数范围检查、服务超时 |
| 建议 | 除零保护、整数溢出、断言保护 |

---

## 六、Agents 快速参考

| Agent | 功能 | 权限 | 触发词 | 项目特色 |
|-------|------|------|--------|----------|
| `build-agent` | Docker 编译, 仅摘要 | auto | `编译` `build` | 环境检测(dev/test) + 编译错误诊断表 |
| `bug-locator` | 定位根因, 输出风险等级 | plan | `定位bug` | RT约束知识 + 常见崩溃模式 + 搜索模板 |
| `bug-fixer` | 修复 + 4项安全自检 | plan | `修复` | RT代码特殊处理 + 编码规范强制 |
| `bug-verify` | 回归 + 四类边界测试 | plan | `验证修复` | 数值/指针/数组/力控边界检查 |
| `bug-report` | 结构化报告 + 安全评估 | plan | `生成报告` | 5层模块依赖 + 安全影响分析 |
| `test-runner` | 测试执行, 仅摘要 | auto | `运行测试` | catkin_make/rostest/gtest filter |
| `security-reviewer` | P0~P3 安全审查 | bypass | `安全审查` | 项目专用搜索模式 + RT/力控/Docker |

### Bug 工作流

```
bug-locator → bug-fixer → bug-verify → bug-report
   (定位)       (修复)       (验证)       (报告)
   输出:        输出:        输出:        输出:
   根因文件     修改文件      验证结果     Bug摘要
   调用链       安全自检      测试记录     严重等级
   修复方向     测试命令      回归影响     影响范围
   风险等级     副作用        边界检查     安全影响
```

---

## 七、RT 实时控制约束速查

`massage_controller_v1` 运行在 **1kHz 硬实时循环**，`update()` 路径中禁止：

| 禁止项 | 安全替代 |
|--------|----------|
| `new` / `malloc` | 预分配为成员变量 |
| `Eigen::MatrixXd` | `Eigen::Matrix<double, R, C>` 固定大小 |
| `std::vector::push_back` | 预分配 `resize()` |
| `std::to_string` (>15字符) | `snprintf` + 栈缓冲区 |
| `ROS_INFO` / `ROS_WARN` | `RT_LOG_INFO()` → `MASSAGE_INFO()` / `SAFETY_RT_INFO()` / `EVTHW_INFO()` |
| `std::cout` / `printf` | 模块专用宏 (含 `[Massage]`/`[Safety]`/`[EvtHW]` 前缀) |
| `std::map::clear()` | 只更新 value，不清空 |
| `sleep` / 阻塞 I/O | 异步处理 |
| `ros::Time::now()` 密集调用 | 缓存时间戳 |

---

## 八、日志查询

审计日志位于 `.claude/logs/`，JSON Lines 格式：

```bash
# 查看今天的操作
cat .claude/logs/audit-$(date +%Y-%m-%d).log | jq .

# 查询所有修改过的文件
cat .claude/logs/audit-*.log | jq -r 'select(.file != null) | .file' | sort -u

# 统计各工具调用次数
cat .claude/logs/audit-*.log | jq -r '.tool' | sort | uniq -c | sort -rn

# 查询特定时间段的操作
cat .claude/logs/audit-*.log | jq 'select(.timestamp >= "2026-06-11T09:00")'
```

---

## 九、新增子仓库

```bash
cd src/<new_repo>
ln -s ../../.claude .claude
```

### 子目录级配置（按需）

```bash
# 为特定目录添加权限（如测试目录需要 Python import 检查）
mkdir -p src/<repo>/test/.claude
cat > src/<repo>/test/.claude/settings.local.json <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(python3:*)"
    ]
  }
}
EOF
```

### 子目录级 CLAUDE.md（按需）

```bash
# 为特定任务定制 Claude 行为
cat > src/<repo>/task_dir/CLAUDE.md <<'EOF'
# 任务说明
...
## 构建命令
...
## 文件权限
只允许修改本目录下的文件
EOF
```

---

## 十、最佳实践

1. **优先使用 Agent 工作流**: 复杂 Bug 走完整四阶段，简单修复用 bug-fixer
2. **push 前自动审查**: `git push` 自动触发 code-reviewing，发现 🔴 问题先修复
3. **信任但验证**: agent 操作后检查修改内容，plan 模式的 agent 每阶段都需确认
4. **最小权限原则**: `settings.local.json` 只添加必要的权限，不开放超出范围
5. **利用 CLAUDE.md**: 为常驻任务目录创建 CLAUDE.md 定制上下文
6. **安全优先**: 涉及力控/硬件/输入的代码必须经过 secure-coding 审查
