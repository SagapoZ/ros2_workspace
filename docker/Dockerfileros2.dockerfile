ARG BASE_IMAGE=osrf/icra2023_ros2_gz_tutorial:roscon2024_tutorial_nvidia
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=jazzy \
    RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    DISPLAY=:0

USER root

# 使用清华 apt 源
RUN sed -i "s@http://.*archive.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list && \
    sed -i "s@http://.*security.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list

# 安装所有依赖（合并 apt install 减少 layer）
RUN apt update && apt install -y --no-install-recommends \
    # 基础工具
    locales \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    lsb-release \
    curl \
    wget \
    git \
    git-lfs \
    python3-pip \
    python3-venv \
    python3-apt \
    # 额外库与中文支持
    alsa-utils \
    python3-tk \
    libc++-dev \
    psmisc \
    bluez \
    bluetooth \
    libnlopt-cxx-dev \
    language-pack-zh-hans \
    language-pack-zh-hans-base \
    fonts-droid-fallback \
    ttf-wqy-zenhei \
    ttf-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    # SSH 服务
    openssh-server && \
    # locale 配置
    locale-gen zh_CN.UTF-8 en_US.UTF-8 && \
    update-locale LANG=${LANG} LC_ALL=${LC_ALL} && \
    # pip 配置 (跳过升级系统 pip，仅配置镜像源)
    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple && \
    pip config set global.break-system-packages true && \
    # git lfs 配置
    git lfs install --system && \
    # 清理 apt 缓存
    rm -rf /var/lib/apt/lists/*

# ROS 2 环境配置（合并 bashrc 相关配置）
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "source /opt/ros/jazzy/setup.bash" >> /root/.profile && \
    echo "if [ -f /root/.bashrc ]; then source /root/.bashrc; fi" > /root/.bash_profile && \
    # Gazebo 别名
    echo "alias gazebo='gz sim'" >> /root/.bashrc && \
    echo "alias gzserver='gz sim -s'" >> /root/.bashrc && \
    echo "alias gzclient='gz sim -g'" >> /root/.bashrc

# 机器人目录
RUN mkdir -p /var/robot/log /var/robot/product /var/robot/calibration && \
    chmod -R 777 /var/robot

# SSH 配置
RUN mkdir -p /run/sshd && \
    sed -i "s/#Port 22/Port 2223/g" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    echo "root:robot" | chpasswd

# 创建工作目录
RUN mkdir -p /workspace

# 安装 Starship 并配置
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes && \
    echo 'eval "$(starship init bash)"' >> /root/.bashrc && \
    mkdir -p /root/.config && \
    printf '%s\n' \
      '# 极简主题 - 最小化' \
      'format = "$directory$git_branch$character "' \
      '' \
      '[character]' \
      'success_symbol = "[>](bold green)"' \
      'error_symbol = "[>](bold red)"' \
      '' \
      '[directory]' \
      'style = "bold cyan"' \
      'truncation_length = 2' \
      '' \
      '[git_branch]' \
      'symbol = " "' \
      'style = "bold green"' \
      > /root/.config/starship.toml

WORKDIR /workspace

RUN echo 'if [[ $- == *i* ]] && [ -d /home/robot/ros2_workspace ]; then cd /home/robot/ros2_workspace; fi' >> /root/.bashrc

WORKDIR /home/robot/ros2_workspace

EXPOSE 2223

CMD ["/usr/sbin/sshd", "-D"]
