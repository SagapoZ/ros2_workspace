ARG BASE_IMAGE=osrf/ros:humble-desktop-full
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=humble \
    RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    DISPLAY=:0

# 非 root 用户，UID/GID 需与宿主机 robot 用户一致（宿主机: id robot -> uid=1000 gid=1000），
# 这样容器内该用户在挂载目录（/home/robot、/var/robot ...）中创建的文件，在宿主机上也是 robot 而不是 root
ARG USERNAME=robot
ARG USER_UID=1000
ARG USER_GID=1000
# 该用户的家目录不能选 /home/robot —— 那个路径在运行时会被 docker-compose 挂载成宿主机的
# /home/robot/easefuture/，用作 home 会导致 .bashrc 等被挂载覆盖掉，登录环境全部丢失
ENV USER_HOME=/home/dev

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
    sudo \
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
    # 编译与调试工具 (VS Code C++ 开发/调试)
    build-essential \
    gdb \
    gdbserver \
    clangd \
    ccache \
    python3-colcon-common-extensions \
    python3-rosdep \
    language-pack-zh-hans \
    language-pack-zh-hans-base \
    fonts-droid-fallback \
    ttf-wqy-zenhei \
    ttf-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    # RMW 实现 (base image 默认不带 cyclonedds)
    ros-humble-rmw-cyclonedds-cpp \
    # ros2_control 相关
    ros-humble-ros2-control \
    ros-humble-ros2-controllers \
    ros-humble-gazebo-ros2-control \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-rqt-controller-manager \
    ros-humble-rqt-joint-trajectory-controller \
    ros-humble-xacro \
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
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "source /opt/ros/humble/setup.bash" >> /root/.profile && \
    echo "if [ -f /root/.bashrc ]; then source /root/.bashrc; fi" > /root/.bash_profile
    # 让 colcon 读取仓库根目录的 colcon_defaults.yaml（clangd 的 compile_commands.json 依赖它）
    #echo "export COLCON_DEFAULTS_FILE=/home/robot/MoxibustionRobotGroup/ros2_workspace/colcon_defaults.yaml" >> /root/.bashrc
    # 注：Gazebo Classic 11（Humble 默认仿真器）自带 gazebo/gzserver/gzclient 命令，无需别名

# 机器人目录
RUN mkdir -p /var/robot/log /var/robot/product /var/robot/calibration && \
    chmod -R 777 /var/robot

# SSH 配置
RUN mkdir -p /run/sshd && \
    sed -i "s/#Port 22/Port 22223/g" /etc/ssh/sshd_config && \
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

# 创建与宿主机 UID/GID 对齐的 robot 用户，日常开发用它登录/exec，容器里创建的文件在宿主机上就是 robot 权限而不是 root
RUN groupadd -g ${USER_GID} ${USERNAME} && \
    useradd -m -d ${USER_HOME} -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME}:${USERNAME}" | chpasswd && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    echo "source /opt/ros/humble/setup.bash" >> ${USER_HOME}/.bashrc && \
    echo "source /opt/ros/humble/setup.bash" >> ${USER_HOME}/.profile && \
    echo "if [ -f ${USER_HOME}/.bashrc ]; then source ${USER_HOME}/.bashrc; fi" > ${USER_HOME}/.bash_profile && \
    echo "export COLCON_DEFAULTS_FILE=/home/robot/MoxibustionRobotGroup/ros2_workspace/colcon_defaults.yaml" >> ${USER_HOME}/.bashrc && \
    echo 'if [[ $- == *i* ]] && [ -d /home/robot/MoxibustionRobotGroup/ ]; then cd /home/robot/MoxibustionRobotGroup/; fi' >> ${USER_HOME}/.bashrc && \
    echo 'eval "$(starship init bash)"' >> ${USER_HOME}/.bashrc && \
    mkdir -p ${USER_HOME}/.config && \
    cp /root/.config/starship.toml ${USER_HOME}/.config/starship.toml && \
    chown -R ${USERNAME}:${USERNAME} ${USER_HOME}

WORKDIR /workspace

RUN echo 'if [[ $- == *i* ]] && [ -d /home/robot/MoxibustionRobotGroup/ ]; then cd /home/robot/MoxibustionRobotGroup/; fi' >> /root/.bashrc

WORKDIR /home/robot/MoxibustionRobotGroup/

EXPOSE 22223

CMD ["/usr/sbin/sshd", "-D"]
