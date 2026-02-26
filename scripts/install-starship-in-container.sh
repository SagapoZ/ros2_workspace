#!/bin/bash

# 一键在容器中安装starship的脚本
# 使用方法：docker cp 此脚本到容器，然后在容器内运行

echo "开始安装starship..."

# 检查是否在容器中
if [ -f /.dockerenv ]; then
    echo "检测到Docker环境"
else
    echo "警告：未检测到Docker环境，请确保在容器内运行此脚本"
fi

# 安装starship
echo "安装starship..."
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# 配置bash
echo "配置bash..."
echo 'eval "$(starship init bash)"' >> ~/.bashrc

# 创建配置目录
mkdir -p ~/.config

# 创建starship配置
echo "创建starship配置..."
cat > ~/.config/starship.toml << 'STARSHIP_EOF'
# 极简主题 - 最小化
format = "$directory$git_branch$character "

[character]
success_symbol = "[>](bold green)"
error_symbol = "[>](bold red)"

[directory]
style = "bold cyan"
truncation_length = 2

[git_branch]
symbol = " "
style = "bold green"
STARSHIP_EOF

echo "安装完成！"
echo "请运行: source ~/.bashrc"
echo "或者重新进入容器即可看到starship主题"
