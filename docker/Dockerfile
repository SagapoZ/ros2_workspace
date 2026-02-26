ARG BASE_IMAGE=osrf/ros:humble-desktop-full-jammy
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=humble \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    DISPLAY=:0

USER root

# 使用清华 apt 源
RUN sed -i "s@http://.*archive.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list && \
    sed -i "s@http://.*security.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list

# 基础依赖与 locale
RUN apt update && apt install -y --no-install-recommends \
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
    python3-distutils \
    python3-apt && \
    locale-gen zh_CN.UTF-8 en_US.UTF-8 && \
    update-locale LANG=${LANG} LC_ALL=${LC_ALL} && \
    python3 -m pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip && \
    pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple && \
    git lfs install --system

# 配置 ROS2 源并安装 ROS 及常用工具
RUN apt update && \
    apt install -y --no-install-recommends \
      ros-${ROS_DISTRO}-desktop \
      python3-rosdep \
      python3-rosinstall \
      python3-rosinstall-generator \
      python3-vcstool \
      python3-colcon-common-extensions \
      build-essential \
      net-tools \
      openssh-server \
      adb \
      jq \
      tzdata \
      libasound2-dev \
      ros-${ROS_DISTRO}-ros2-control \
      ros-${ROS_DISTRO}-ros2-controllers \
      ros-${ROS_DISTRO}-gazebo-ros-pkgs \
      ros-${ROS_DISTRO}-moveit \
      ros-${ROS_DISTRO}-xacro \
      ros-${ROS_DISTRO}-navigation2 \
      libyaml-cpp-dev \
      libudev-dev \
      libnm-dev \
      gdb \
      libopus-dev \
      xterm \
      lcov && \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc

# 额外库与中文支持
RUN apt install -y --no-install-recommends \
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
      fonts-arphic-uming && \
    rm -rf /var/lib/apt/lists/*

# 机器人目录
RUN mkdir -p /var/robot/log /var/robot/product /var/robot/calibration && \
    chmod -R 777 /var/robot

# SSH 配置
RUN mkdir -p /run/sshd && \
    sed -i "s/#Port 22/Port 2223/g" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    echo "root:robot" | chpasswd

# 创建挂载目录 & shell 行为
RUN mkdir -p /home/robot/ros2_workspace && \
    sed -i 's/\[ -z "\$PS1" \] && return/#\[ -z "\$PS1" \] \&\& return/g' ~/.bashrc && \
    cat <<'EOF' >> /root/.bashrc
if [ -d /home/robot/ros2_workspace ]; then
  cd /home/robot/ros2_workspace
fi
EOF

# 安装 Starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes && \
    echo 'eval "$(starship init bash)"' >> /root/.bashrc && \
    mkdir -p /root/.config && \
    echo '# 极简主题 - 最小化' > /root/.config/starship.toml && \
    echo 'format = "$directory$git_branch$character "' >> /root/.config/starship.toml && \
    echo '' >> /root/.config/starship.toml && \
    echo '[character]' >> /root/.config/starship.toml && \
    echo 'success_symbol = "[>](bold green)"' >> /root/.config/starship.toml && \
    echo 'error_symbol = "[>](bold red)"' >> /root/.config/starship.toml && \
    echo '' >> /root/.config/starship.toml && \
    echo '[directory]' >> /root/.config/starship.toml && \
    echo 'style = "bold cyan"' >> /root/.config/starship.toml && \
    echo 'truncation_length = 2' >> /root/.config/starship.toml && \
    echo '' >> /root/.config/starship.toml && \
    echo '[git_branch]' >> /root/.config/starship.toml && \
    echo 'symbol = " "' >> /root/.config/starship.toml && \
    echo 'style = "bold green"' >> /root/.config/starship.toml

WORKDIR /home/robot/ros2_workspace

EXPOSE 2223

CMD ["/usr/sbin/sshd", "-D"]
