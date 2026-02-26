param(
    [Parameter(Position=0)]
    [string]$cmd = "help"
)

$wslDistro = if ($env:WSL_DISTRO_NAME) { $env:WSL_DISTRO_NAME } elseif ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "Ubuntu" }
$wslWorkdir = if ($env:WSL_WORKDIR) { $env:WSL_WORKDIR } else { "/home/robot/ros2_workspace" }
$image = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "ros2-dev:latest" }
$container = if ($env:CONTAINER_NAME) { $env:CONTAINER_NAME } else { "ros2_dev" }
$composeFile = if ($env:COMPOSE_FILE) { $env:COMPOSE_FILE } else { "docker/docker-compose.yml" }
$baseImage = if ($env:BASE_IMAGE) { $env:BASE_IMAGE } else { "osrf/ros:humble-desktop-full-jammy" }

$envExports = @()
$envExports += "IMAGE_NAME='$image'"
$envExports += "CONTAINER_NAME='$container'"
$envExports += "COMPOSE_FILE='$composeFile'"
$envExports += "BASE_IMAGE='$baseImage'"

$joinedExports = [string]::Join(" ", $envExports)
$wslCommand = "cd $wslWorkdir && $joinedExports ./scripts/dev.sh $cmd"

Write-Output ">>> Executing in WSL ($wslDistro): $cmd"
wsl -d $wslDistro -- bash -lc "$wslCommand"
