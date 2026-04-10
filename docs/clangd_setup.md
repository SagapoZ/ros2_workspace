# clangd 配置

**无需在每个包下创建 .clangd**，只需工作空间根目录的配置即可。

## 一、配置方式（二选一）

### 方式 A：.clangd + colcon build（推荐）

- 根目录已有 `.clangd`，指向 `build/`
- `colcon_defaults.yaml` 会让 `colcon build` 自动生成 `compile_commands.json`
- clangd 会使用 `build/compile_commands.json`

### 方式 B：VS Code/Cursor 插件配置

根目录已有 `.vscode/settings.json`：

```json
{
  "clangd.arguments": ["--compile-commands-dir=${workspaceFolder}/build"]
}
```

同样需要先执行一次 `colcon build`，让 `build/compile_commands.json` 存在。

## 二、日常使用

```bash
colcon build

source install/setup.bash
```

`colcon build` 会根据 `colcon_defaults.yaml` 传入 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`。

## 三、新增 C++ 包

无需额外配置，直接重新执行 `colcon build` 即可刷新 `build/compile_commands.json`。

## 四、仅用 colcon build（不合并）

当前配置已经是直接使用 `colcon build`，无需合并。
