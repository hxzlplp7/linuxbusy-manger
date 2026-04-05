#!/bin/bash

# ====================================================
# Lookbusy 管理脚本 (针对甲骨文云保活设计)
# 教程来源：jcnf/荒岛
# 脚本作者：Antigravity
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 变量定义
SERVICE_PATH="/etc/systemd/system/lookbusy.service"
BINARY_PATH="/usr/local/bin/lookbusy"
SRC_URL="http://www.devin.com/lookbusy/download/lookbusy-1.4.tar.gz"
TEMP_DIR="/tmp/lookbusy_install"

# 权限检查
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：该脚本必须以 root 权限运行！${NC}"
   exit 1
fi

# 参数处理 (辅助一键安装)
handle_args() {
    case $1 in
        1|install)
            install_lookbusy
            ;;
        2|start)
            # 允许直接带参数运行，例如: ./script.sh start 20 1G
            manage_service "$2" "$3"
            ;;
        3|stop)
            stop_service
            ;;
        5|uninstall)
            uninstall_lookbusy_auto
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            echo -e "可用参数: install, start, stop, uninstall"
            exit 1
            ;;
    esac
    exit 0
}

# 核心功能：检查是否安装
is_installed() {
    if [[ -f "$BINARY_PATH" ]]; then
        return 0
    else
        return 1
    fi
}

# 核心功能：服务运行状态
is_running() {
    if systemctl is-active --quiet lookbusy.service; then
        return 0
    else
        return 1
    fi
}

# 菜单：安装 lookbusy
install_lookbusy() {
    if is_installed; then
        echo -e "${YELLOW}lookbusy 已经安装在 $BINARY_PATH${NC}"
        return
    fi

    echo -e "${BLUE}开始安装依赖 (curl, build-essential)...${NC}"
    apt -y update && apt -y install curl build-essential

    echo -e "${BLUE}正在下载 lookbusy 源码...${NC}"
    mkdir -p "$TEMP_DIR"
    curl -L "$SRC_URL" -o "$TEMP_DIR/lookbusy-1.4.tar.gz"
    
    if [[ ! -f "$TEMP_DIR/lookbusy-1.4.tar.gz" ]]; then
        echo -e "${RED}下载失败，请检查网络！${NC}"
        return
    fi

    echo -e "${BLUE}开始解压并编译...${NC}"
    cd "$TEMP_DIR" || exit
    tar -xzvf lookbusy-1.4.tar.gz
    cd lookbusy-1.4/ || exit
    ./configure && make && make install

    if is_installed; then
        echo -e "${GREEN}✔ lookbusy 安装成功！${NC}"
    else
        echo -e "${RED}❌ 安装失败，请检查编译输出。${NC}"
    fi

    # 清理临时文件
    rm -rf "$TEMP_DIR"
}

# 菜单：启动/更新服务
manage_service() {
    if ! is_installed; then
        echo -e "${RED}错误：未发现 lookbusy 进程，请先进行安装。${NC}"
        return
    fi

    local cpu_val=$1
    local mem_val=$2

    if [[ -z "$cpu_val" || -z "$mem_val" ]]; then
        echo -e "${YELLOW}--- 配置负载参数 ---${NC}"
        read -p "请输入 CPU 使用率 (0-100，建议 20): " cpu_val
        cpu_val=${cpu_val:-20}
        
        read -p "请输入内存占用大小 (例如 5120MB 或 1G): " mem_val
        mem_val=${mem_val:-5120MB}
    fi

    echo -e "${BLUE}正在创建/更新 systemd 服务...${NC}"
    cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=lookbusy service
 
[Service]
Type=simple
ExecStart=$BINARY_PATH -c $cpu_val -m $mem_val
Restart=always
RestartSec=10
KillSignal=SIGINT
 
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now lookbusy.service

    if is_running; then
        echo -e "${GREEN}✔ 负载服务已启动！(CPU: $cpu_val%, Memory: $mem_val)${NC}"
    else
        echo -e "${RED}❌ 服务启动失败，请运行 'journalctl -u lookbusy' 查看错误。${NC}"
    fi
}

# 菜单：停止负载
stop_service() {
    if [[ ! -f "$SERVICE_PATH" ]]; then
        echo -e "${YELLOW}服务文件不存在。${NC}"
        return
    fi

    echo -e "${BLUE}正在停止服务...${NC}"
    systemctl disable --now lookbusy.service
    echo -e "${GREEN}✔ 负载服务已停止并禁用自启。${NC}"
}

# 菜单：卸载 (交互式)
uninstall_lookbusy() {
    echo -e "${YELLOW}警告：这将彻底卸载 lookbusy 及其配置！${NC}"
    read -p "确定继续吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    uninstall_lookbusy_auto
}

# 自动化卸载 (非交互)
uninstall_lookbusy_auto() {
    stop_service
    rm -f "$SERVICE_PATH"
    rm -f "$BINARY_PATH"
    systemctl daemon-reload
    echo -e "${GREEN}✔ 卸载完成。${NC}"
}

# 菜单：查看状态
show_status() {
    echo -e "${BLUE}========================================${NC}"
    echo -n "安装状态: "
    if is_installed; then echo -e "${GREEN}已安装${NC}"; else echo -e "${RED}未安装${NC}"; fi
    
    echo -n "运行状态: "
    if is_running; then 
        echo -e "${GREEN}正在运行${NC}"
        echo -e "${BLUE}当前进程配置:${NC}"
        ps aux | grep lookbusy | grep -v grep
    else 
        echo -e "${RED}已停止${NC}"
    fi
    echo -e "${BLUE}========================================${NC}"
    echo -e "提示：即将进入 top 视图查看实时负载，按 'q' 退出并返回菜单。"
    sleep 2
    top -d 2
}

# 如果有命令行参数，则直接处理
if [[ -n "$1" ]]; then
    handle_args "$@"
fi

# 主循环
while true; do
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}      Lookbusy VPS 管理菜单 (V1.0)      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "1) ${GREEN}安装 lookbusy${NC} (仅需运行一次)"
    echo -e "2) ${YELLOW}启动/更新 负载配置${NC} (设置 CPU/内存)"
    echo -e "3) ${RED}停止 负载服务${NC}"
    echo -e "4) 查看状态 & 实时监控"
    echo -e "5) 彻底卸载"
    echo -e "0) 退出"
    echo -e "${BLUE}========================================${NC}"
    read -p "请选择操作 [0-5]: " choice

    case $choice in
        1) install_lookbusy ;;
        2) manage_service ;;
        3) stop_service ;;
        4) show_status ;;
        5) uninstall_lookbusy ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo -e "${RED}输入无效，请重新选择。${NC}" ;;
    esac
done
