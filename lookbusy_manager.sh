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
SCRIPT_PATH=$(readlink -f "$0")
PERMANENT_PATH="/usr/local/bin/lookbusy-manager"

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

# 核心功能：获取系统资源静态信息
get_system_info() {
    CPU_CORES=$(nproc)
    MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
    MEM_FREE=$(free -m | awk '/^Mem:/ {print $7}')
    echo -e "${BLUE}--- 系统静态资源概览 ---${NC}"
    echo -e "CPU 核心总数: ${YELLOW}${CPU_CORES}${NC} 核"
    echo -e "总内存容量  : ${YELLOW}${MEM_TOTAL}${NC} MB"
    echo -e "当前空闲内存: ${YELLOW}${MEM_FREE}${NC} MB"
    echo -e "${BLUE}------------------------${NC}"
}

# 核心功能：获取当前负载动态指标
get_current_usage() {
    # CPU 占用率通过 top 快照计算 (Debian/Ubuntu 兼容)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4+$6}')
    # 如果 top 输出格式有差异导致无法获取，则设置默认值
    if [[ -z "$CPU_USAGE" ]]; then CPU_USAGE="0.0"; fi
    
    # 内存占用百分比
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    
    # 状态条渲染
    echo -n -e "当前系统占用:  "
    
    # CPU 色彩指示
    if (( $(echo "$CPU_USAGE < 30" | bc -l 2>/dev/null || [ "${CPU_USAGE%.*}" -lt 30 ] ) )); then
        echo -n -e "CPU: ${GREEN}${CPU_USAGE}%${NC} | "
    elif (( $(echo "$CPU_USAGE < 70" | bc -l 2>/dev/null || [ "${CPU_USAGE%.*}" -lt 70 ] ) )); then
        echo -n -e "CPU: ${YELLOW}${CPU_USAGE}%${NC} | "
    else
        echo -n -e "CPU: ${RED}${CPU_USAGE}%${NC} | "
    fi
    
    # 内存色彩指示
    if (( $(echo "$MEM_USAGE < 50" | bc -l 2>/dev/null || [ "${MEM_USAGE%.*}" -lt 50 ] ) )); then
        echo -e "MEM: ${GREEN}${MEM_USAGE}%${NC}"
    elif (( $(echo "$MEM_USAGE < 85" | bc -l 2>/dev/null || [ "${MEM_USAGE%.*}" -lt 85 ] ) )); then
        echo -e "MEM: ${YELLOW}${MEM_USAGE}%${NC}"
    else
        echo -e "MEM: ${RED}${MEM_USAGE}%${NC}"
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

    # 设置快捷指令
    set_shortcut
}

# 核心功能：检查快捷指令状态
check_shortcut_status() {
    local found=""
    # 遍历常用二进制目录寻找指向此脚本的链接
    for cmd in /usr/local/bin/* /usr/bin/*; do
        if [[ -L "$cmd" && "$(readlink -f "$cmd")" == "$SCRIPT_PATH" ]]; then
            found=$(basename "$cmd")
            break
        fi
    done
    
    if [[ -n "$found" ]]; then
        echo -e "快捷指令状态: ${GREEN}已设置 ($found)${NC}"
    else
        echo -e "快捷指令状态: ${RED}未设置${NC}"
    fi
}

# 核心功能：设置快捷指令 (增强版)
set_shortcut() {
    echo -e "\n${BLUE}--- 设置/加固 快捷启动指令 ---${NC}"
    
    # 1. 询问是否固化脚本位置
    if [[ "$SCRIPT_PATH" != "$PERMANENT_PATH" ]]; then
        echo -e "${YELLOW}提示：将脚本移动到系统目录可防止因原始目录删除而导致快捷指令失效。${NC}"
        read -p "是否将脚本固化到 $PERMANENT_PATH？(y/n, 默认y): " move_confirm
        move_confirm=${move_confirm:-y}
        if [[ "$move_confirm" == "y" ]]; then
            cp -f "$SCRIPT_PATH" "$PERMANENT_PATH"
            chmod +x "$PERMANENT_PATH"
            SCRIPT_PATH="$PERMANENT_PATH"
            echo -e "${GREEN}✔ 脚本已加固。${NC}"
        fi
    fi

    # 2. 设置软链接
    read -p "请输入欲使用的快捷指令名称 (建议 lb 或 lookbusy): " cmd_name
    cmd_name=${cmd_name:-lb}
    local target_path="/usr/local/bin/$cmd_name"

    # 3. 冲突检测 (核心：处理 lb 冲突)
    if command -v "$cmd_name" > /dev/null; then
        local existing_path=$(which "$cmd_name")
        if [[ "$existing_path" != "$target_path" ]]; then
            echo -e "${RED}警告：系统已存在同名命令 '$cmd_name'！${NC}"
            echo -e "${RED}路径: $existing_path${NC}"
            read -p "是否强制覆盖（可能影响系统其他软件）？(y/n): " force_confirm
            if [[ "$force_confirm" != "y" ]]; then 
                echo -e "${YELLOW}取消设置，建议换个名字（如 lbz）。${NC}"
                return 
            fi
        fi
    fi

    ln -sf "$SCRIPT_PATH" "$target_path"
    chmod +x "$target_path"
    
    # 4. 验证
    if command -v "$cmd_name" > /dev/null; then
        echo -e "${GREEN}✔ 快捷指令 '$cmd_name' 设置成功！${NC}"
        echo -e "以后只需输入 ${YELLOW}$cmd_name${NC} 即可快速管理负载。"
    else
        echo -e "${RED}❌ 设置失败，请检查 /usr/local/bin 是否在 PATH 中。${NC}"
    fi
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
        get_system_info
        get_current_usage
        echo -e "\n${YELLOW}提示：建议设置 CPU 占用率在 15-25% 之间。${NC}"
        echo -e "${YELLOW}提示：内存设置【严禁超过】当前可用内存 (${MEM_FREE}MB)。${NC}"
        
        while true; do
            read -p "请输入欲占用的 CPU 使用率 (0-100): " cpu_val
            if [[ "$cpu_val" =~ ^[0-9]+$ ]] && [ "$cpu_val" -le 100 ]; then break; fi
            echo -e "${RED}输入错误，请输入 0 到 100 之间的数字。${NC}"
        done

        while true; do
            read -p "请输入欲占用的内存大小 (例如 200MB 或 1G): " mem_val
            # 基础校验：如果是以 MB 结尾，检查数值是否超过可用内存
            if [[ "$mem_val" =~ ^([0-9]+)MB$ ]]; then
                val=${BASH_REMATCH[1]}
                if [ "$val" -ge "$MEM_FREE" ]; then
                    echo -e "${RED}警告：设置值 ($val MB) 超过可用内存 ($MEM_FREE MB)，会导致服务启动失败！${NC}"
                    continue
                fi
            fi
            if [[ -n "$mem_val" ]]; then break; fi
        done
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
    
    # 清理快捷指令 (查找指向此脚本或固化路径的软链接)
    for cmd in /usr/local/bin/* /usr/bin/*; do
        if [[ -L "$cmd" ]]; then
            local link_target=$(readlink -f "$cmd")
            if [[ "$link_target" == "$SCRIPT_PATH" || "$link_target" == "$PERMANENT_PATH" ]]; then
                rm -f "$cmd"
                echo -e "${GREEN}✔ 已移除快捷指令: $(basename "$cmd")${NC}"
            fi
        fi
    done

    # 清理固化脚本
    [[ -f "$PERMANENT_PATH" ]] && rm -f "$PERMANENT_PATH"

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
    check_shortcut_status
    get_current_usage
    echo -e "1) ${GREEN}安装 lookbusy${NC} (仅需运行一次)"
    echo -e "2) ${YELLOW}启动/更新 负载配置${NC} (设置 CPU/内存)"
    echo -e "3) ${RED}停止 负载服务${NC}"
    echo -e "4) 查看状态 & 实时监控"
    echo -e "5) 彻底卸载"
    echo -e "6) ${BLUE}设置/修改 快捷启动指令${NC}"
    echo -e "0) 退出"
    echo -e "${BLUE}========================================${NC}"
    read -p "请选择操作 [0-6]: " choice

    case $choice in
        1) install_lookbusy ;;
        2) manage_service ;;
        3) stop_service ;;
        4) show_status ;;
        5) uninstall_lookbusy ;;
        6) set_shortcut ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo -e "${RED}输入无效，请重新选择。${NC}" ;;
    esac
done
