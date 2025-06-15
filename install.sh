#!/bin/bash

# ========================================================
# GOSTC 统一管理工具箱 v1.0
# 最后更新: 2024-06-15
# 远程地址: https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh
# ========================================================

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 配置参数
SCRIPT_VERSION="1.0"
SCRIPT_NAME="gotool"
SCRIPT_SERVICE="gotool-toolbox"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
STAT_ID="KqjQwhUvnroCsYNS"
STAT_CK="KqjQwhUvnroCsYNS"

# 服务端配置
SERVER_TARGET_DIR="/usr/local/gostc-admin"
SERVER_BINARY_NAME="server"
SERVER_SERVICE_NAME="gostc-admin"
SERVER_CONFIG_FILE="${SERVER_TARGET_DIR}/config.yml"

# 客户端配置
CLIENT_TARGET_DIR="/usr/local/bin"
CLIENT_BINARY_NAME="gostc"
CLIENT_SERVICE_NAME="gostc"

# 发送统计信息
send_statistics() {
    local action=$1
    local component=$2
    
    curl -s -o /dev/null "https://sdk.51.la/perf/js-sdk?\
id=${STAT_ID}&ck=${STAT_CK}&\
event=script_run&\
action=${action}&\
component=${component}&\
version=${SCRIPT_VERSION}" >/dev/null 2>&1 &
}

# 显示标题
print_header() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}GOSTC 统一管理工具箱${PURPLE}                   ║"
    echo "║                                                            ║"
    echo -e "║              ${WHITE}版本: ${SCRIPT_VERSION}    远程更新: ${REMOTE_SCRIPT_URL}${PURPLE} ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示服务状态
show_service_status() {
    local service_name=$1
    local binary_path=$2
    
    echo -e "${CYAN}════════════════ 服务状态 ═════════════════${NC}"
    
    # 检查二进制文件是否存在
    if [ -f "$binary_path" ]; then
        echo -e "${GREEN}✓ 已安装: ${WHITE}$binary_path${NC}"
    else
        echo -e "${RED}✗ 未安装: ${WHITE}$binary_path${NC}"
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}✓ 服务运行中: ${WHITE}$service_name${NC}"
    elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        echo -e "${YELLOW}⚠ 服务已安装但未运行: ${WHITE}$service_name${NC}"
    else
        echo -e "${RED}✗ 服务未安装: ${WHITE}$service_name${NC}"
    fi
    
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
}

# 安装工具箱服务
install_toolbox_service() {
    # 检查是否已安装
    if systemctl is-enabled "$SCRIPT_SERVICE" >/dev/null 2>&1; then
        return
    fi
    
    echo -e "${YELLOW}▶ 正在安装工具箱服务...${NC}"
    
    # 创建服务文件
    sudo tee /etc/systemd/system/${SCRIPT_SERVICE}.service >/dev/null <<EOF
[Unit]
Description=GOSTC Management Toolbox Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/${SCRIPT_NAME}
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

    # 复制脚本到系统目录
    sudo cp "$0" "/usr/local/bin/${SCRIPT_NAME}"
    sudo chmod +x "/usr/local/bin/${SCRIPT_NAME}"
    
    # 启用并启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable "$SCRIPT_SERVICE" >/dev/null 2>&1
    sudo systemctl start "$SCRIPT_SERVICE"
    
    echo -e "${GREEN}✓ 工具箱服务安装完成!${NC}"
    echo -e "${BLUE}您现在可以使用命令: ${WHITE}gotool ${BLUE}来运行工具箱${NC}"
    sleep 2
}

# 更新脚本
update_script() {
    echo -e "${YELLOW}▶ 正在检查更新...${NC}"
    
    # 获取远程脚本内容
    remote_content=$(curl -s "$REMOTE_SCRIPT_URL")
    
    if [ -z "$remote_content" ]; then
        echo -e "${RED}✗ 无法获取远程脚本${NC}"
        return 1
    fi
    
    # 提取远程版本号
    remote_version=$(echo "$remote_content" | grep 'SCRIPT_VERSION=' | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        echo -e "${RED}✗ 无法获取远程版本号${NC}"
        return 1
    fi
    
    # 比较版本
    if [ "$remote_version" == "$SCRIPT_VERSION" ]; then
        echo -e "${GREEN}✓ 当前已是最新版本 (v${SCRIPT_VERSION})${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}▶ 发现新版本: v${remote_version}${NC}"
    echo -e "${BLUE}当前版本: v${SCRIPT_VERSION}${NC}"
    
    read -p "$(echo -e "${BLUE}是否要更新? (y/n, 默认y): ${NC}")" confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}▶ 已取消更新${NC}"
        return 0
    fi
    
    # 备份当前脚本
    backup_file="${0}_backup_$(date +%Y%m%d%H%M%S)"
    cp "$0" "$backup_file"
    
    # 下载新版本
    echo -e "${YELLOW}▶ 正在下载新版本...${NC}"
    if curl -s -o "$0" "$REMOTE_SCRIPT_URL"; then
        chmod +x "$0"
        echo -e "${GREEN}✓ 更新成功! 新版本: v${remote_version}${NC}"
        echo -e "${YELLOW}▶ 请重新运行脚本${NC}"
        
        # 重启工具箱服务
        if systemctl is-active --quiet "$SCRIPT_SERVICE"; then
            sudo systemctl restart "$SCRIPT_SERVICE"
        fi
        
        exit 0
    else
        # 恢复备份
        mv "$backup_file" "$0"
        echo -e "${RED}✗ 更新失败，已恢复原始版本${NC}"
        return 1
    fi
}

# 服务端安装
install_server() {
    print_header
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务端安装向导${PURPLE}              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 检查是否已安装
    if [ -f "${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}" ]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}3. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                # 完全重新安装
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo systemctl stop "$SERVER_SERVICE_NAME" 2>/dev/null
                sudo rm -rf "${SERVER_TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                return
                ;;
            *)
                # 更新操作
                echo -e "${YELLOW}▶ 开始更新服务端到最新版本...${NC}"
                UPDATE_MODE=true
                INSTALL_MODE="update"
                ;;
        esac
        echo ""
    fi
    
    # 选择版本
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "${CYAN}1. ${WHITE}普通版本${BLUE} (默认)"
    echo -e "${CYAN}2. ${WHITE}商业版本${BLUE} (需要授权)"
    echo -e "${NC}"
    
    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice
    
    # 设置下载URL
    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}▶ 您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac
    
    echo ""
    echo -e "${BLUE}▶ 开始安装 ${PURPLE}服务端 ${BLUE}(${VERSION_NAME})${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"
    
    # 架构检测
    FILE_SUFFIX=""
    case "$ARCH" in
        "x86_64")
            FILE_SUFFIX="amd64_v1"
            [ "$OS" = "linux" ] && {
                grep -q "avx512" /proc/cpuinfo 2>/dev/null && FILE_SUFFIX="amd64_v3"
                grep -q "avx2" /proc/cpuinfo 2>/dev/null && FILE_SUFFIX="amd64_v1"
            }
            ;;
        "i"*"86")          FILE_SUFFIX="386_sse2" ;;
        "aarch64"|"arm64") FILE_SUFFIX="arm64_v8.0" ;;
        "armv7l")          FILE_SUFFIX="arm_7" ;;
        "armv6l")          FILE_SUFFIX="arm_6" ;;
        "armv5l")          FILE_SUFFIX="arm_5" ;;
        "mips64")
            lscpu 2>/dev/null | grep -qi "little endian" && \
                FILE_SUFFIX="mips64le_hardfloat" || \
                FILE_SUFFIX="mips64_hardfloat"
            ;;
        "mips")
            if lscpu 2>/dev/null | grep -qi "FPU"; then
                FLOAT="hardfloat"
            else
                FLOAT="softfloat"
            fi
            lscpu 2>/dev/null | grep -qi "little endian" && \
                FILE_SUFFIX="mipsle_$FLOAT" || \
                FILE_SUFFIX="mips_$FLOAT"
            ;;
        "riscv64")         FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x")           FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}"
            sleep 2
            return
            ;;
    esac
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 构建下载URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$SERVER_TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        sleep 3
        return
    }
    
    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE_NAME"
    fi
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${SERVER_TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CONFIG_FILE" "${SERVER_CONFIG_FILE}.bak" 2>/dev/null
        
        # 删除旧文件但保留配置文件
        sudo find "${SERVER_TARGET_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        
        # 恢复配置文件
        sudo mv -f "${SERVER_CONFIG_FILE}.bak" "$SERVER_CONFIG_FILE" 2>/dev/null
    else
        # 全新安装模式
        sudo rm -f "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME"  # 清理旧版本
    fi
    
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$SERVER_TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$SERVER_TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        sleep 2
        return
    fi
    
    # 设置权限
    if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" ]; then
        sudo chmod 755 "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY_NAME${NC}"
        sleep 2
        return
    fi
    
    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" service install "$@"
    fi
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE_NAME"
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVER_SERVICE_NAME}${NC}"
    fi
    
    # 安装完成提示
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}${INSTALL_MODE:-安装}完成${PURPLE}                   ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  操作类型: ${WHITE}$([ "$UPDATE_MODE" = true ] && echo "更新" || echo "${INSTALL_MODE:-安装}")${PURPLE}                     ║"
    echo -e "║  版本: ${WHITE}${VERSION_NAME}${PURPLE}                             ║"
    echo -e "║  安装目录: ${WHITE}$SERVER_TARGET_DIR${PURPLE}                     ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)                          ║"
    echo -e "║  访问地址: ${WHITE}http://localhost:8080${PURPLE}             ║"
    echo -e "║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVER_SERVICE_NAME}${PURPLE} ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 显示初始凭据（仅在新安装或重新安装时显示）
    if [ ! -f "$SERVER_CONFIG_FILE" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}按任意键返回主菜单...${NC}")"
}

# 服务端管理
manage_server() {
    while true; do
        print_header
        show_service_status "$SERVER_SERVICE_NAME" "${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}"
        
        echo -e "${BLUE}请选择服务端操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端${NC}"
        echo -e "${CYAN}2. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}3. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}4. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}5. ${WHITE}卸载服务端${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -rp "请输入选项编号 (0-5): " choice
        
        case $choice in
            1)
                install_server
                send_statistics "install" "server"
                ;;
            2)
                echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                sudo systemctl start "$SERVER_SERVICE_NAME"
                sleep 2
                send_statistics "start" "server"
                ;;
            3)
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo systemctl stop "$SERVER_SERVICE_NAME"
                sleep 2
                send_statistics "stop" "server"
                ;;
            4)
                echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                sudo systemctl restart "$SERVER_SERVICE_NAME"
                sleep 2
                send_statistics "restart" "server"
                ;;
            5)
                echo -e "${RED}▶ 确定要卸载服务端吗? (y/n): ${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}▶ 正在卸载服务端...${NC}"
                    sudo systemctl stop "$SERVER_SERVICE_NAME" 2>/dev/null
                    sudo systemctl disable "$SERVER_SERVICE_NAME" 2>/dev/null
                    sudo rm -f "/etc/systemd/system/${SERVER_SERVICE_NAME}.service"
                    sudo rm -f "/etc/systemd/system/${SERVER_SERVICE_NAME}.service"
                    sudo systemctl daemon-reload
                    sudo rm -rf "$SERVER_TARGET_DIR"
                    echo -e "${GREEN}✓ 服务端已卸载${NC}"
                    send_statistics "uninstall" "server"
                else
                    echo -e "${BLUE}▶ 卸载已取消${NC}"
                fi
                sleep 2
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}✗ 无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 验证服务器地址
validate_server_address() {
    local address=$1
    local use_tls=$2
    
    # 添加http://或https://前缀
    if [[ "$use_tls" == "true" ]]; then
        if [[ "$address" != http* ]]; then
            address="https://$address"
        fi
    else
        if [[ "$address" != http* ]]; then
            address="http://$address"
        fi
    fi
    
    # 验证服务器是否可达
    echo -e "${BLUE}▷ 验证服务器地址: ${WHITE}$address${NC}"
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$address")
    
    if [ "$status_code" -eq 200 ]; then
        echo -e "${GREEN}✓ 服务器验证成功 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 安装客户端组件
install_client_component() {
    local component_type=$1
    
    echo ""
    echo -e "${BLUE}▶ 开始安装 ${WHITE}${component_type}${BLUE} 组件${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"
    
    # 架构检测
    FILE_SUFFIX=""
    case "$ARCH" in
        "x86_64") FILE_SUFFIX="amd64_v1" ;;
        "i"*"86") FILE_SUFFIX="386_sse2" ;;
        "aarch64"|"arm64") FILE_SUFFIX="arm64_v8.0" ;;
        "armv7l") FILE_SUFFIX="arm_7" ;;
        "armv6l") FILE_SUFFIX="arm_6" ;;
        "armv5l") FILE_SUFFIX="arm_5" ;;
        "mips64") lscpu 2>/dev/null | grep -qi "little endian" && FILE_SUFFIX="mips64le_hardfloat" || FILE_SUFFIX="mips64_hardfloat" ;;
        "mips")
            if lscpu 2>/dev/null | grep -qi "FPU"; then
                FLOAT="hardfloat"
            else
                FLOAT="softfloat"
            fi
            lscpu 2>/dev/null | grep -qi "little endian" && FILE_SUFFIX="mipsle_$FLOAT" || FILE_SUFFIX="mips_$FLOAT"
            ;;
        "riscv64") FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x") FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}"
            sleep 2
            return 1
            ;;
    esac
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$CLIENT_TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        sleep 3
        return 1
    }
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${CLIENT_TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo rm -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$CLIENT_TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$CLIENT_TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        sleep 2
        return 1
    fi
    
    # 设置权限
    if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME" ]; then
        sudo chmod 755 "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${CLIENT_TARGET_DIR}/${CLIENT_BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $CLIENT_BINARY_NAME${NC}"
        sleep 2
        return 1
    fi
    
    # 清理
    rm -f "$FILE_NAME"
    return 0
}

# 安装节点
install_node() {
    if ! install_client_component "节点"; then
        return
    fi
    
    # 配置提示
    echo ""
    echo -e "${BLUE}▶ 节点配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 节点密钥 (由服务端提供)"
    echo -e "  - (可选) 网关代理地址${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    if [[ "$tls_choice" =~ ^[Yy]$ ]]; then
        use_tls="true"
    fi
    
    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
        fi
    done
    
    # 节点密钥
    local node_key=""
    while [ -z "$node_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入节点密钥: ${NC}")" node_key
        if [ -z "$node_key" ]; then
            echo -e "${RED}✗ 节点密钥不能为空${NC}"
        fi
    done
    
    # 网关代理选项
    local proxy_base_url=""
    read -p "$(echo -e "${BLUE}▷ 是否使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "$(echo -e "${BLUE}▷ 输入网关地址 (包含http/https前缀): ${NC}")" proxy_url
            if [[ "$proxy_url" =~ ^https?:// ]]; then
                proxy_base_url="$proxy_url"
                break
            else
                echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
            fi
        done
    fi
    
    # 构建安装命令
    local install_cmd="sudo $CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置节点${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        sleep 2
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        sleep 2
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}节点安装成功${BLUE}                  ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}节点${BLUE}                                   ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_TARGET_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url${BLUE}               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}按任意键返回...${NC}")"
}

# 安装客户端
install_client() {
    if ! install_client_component "客户端"; then
        return
    fi
    
    # 配置提示
    echo ""
    echo -e "${BLUE}▶ 客户端配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 客户端密钥 (由服务端提供)${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    if [[ "$tls_choice" =~ ^[Yy]$ ]]; then
        use_tls="true"
    fi
    
    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
        fi
    done
    
    # 客户端密钥
    local client_key=""
    while [ -z "$client_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入客户端密钥: ${NC}")" client_key
        if [ -z "$client_key" ]; then
            echo -e "${RED}✗ 客户端密钥不能为空${NC}"
        fi
    done
    
    # 构建安装命令
    local install_cmd="sudo $CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        sleep 2
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        sleep 2
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}客户端安装成功${BLUE}                ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}客户端${BLUE}                                 ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_TARGET_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}按任意键返回...${NC}")"
}

# 节点/客户端管理
manage_client() {
    while true; do
        print_header
        show_service_status "$CLIENT_SERVICE_NAME" "${CLIENT_TARGET_DIR}/${CLIENT_BINARY_NAME}"
        
        echo -e "${BLUE}请选择节点/客户端操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装节点${NC}"
        echo -e "${CYAN}2. ${WHITE}安装客户端${NC}"
        echo -e "${CYAN}3. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}4. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}5. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}6. ${WHITE}卸载节点/客户端${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -rp "请输入选项编号 (0-6): " choice
        
        case $choice in
            1)
                install_node
                send_statistics "install" "node"
                ;;
            2)
                install_client
                send_statistics "install" "client"
                ;;
            3)
                echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                sudo systemctl start "$CLIENT_SERVICE_NAME"
                sleep 2
                send_statistics "start" "client"
                ;;
            4)
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo systemctl stop "$CLIENT_SERVICE_NAME"
                sleep 2
                send_statistics "stop" "client"
                ;;
            5)
                echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                sudo systemctl restart "$CLIENT_SERVICE_NAME"
                sleep 2
                send_statistics "restart" "client"
                ;;
            6)
                echo -e "${RED}▶ 确定要卸载节点/客户端吗? (y/n): ${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}▶ 正在卸载节点/客户端...${NC}"
                    sudo systemctl stop "$CLIENT_SERVICE_NAME" 2>/dev/null
                    sudo systemctl disable "$CLIENT_SERVICE_NAME" 2>/dev/null
                    sudo rm -f "/etc/systemd/system/${CLIENT_SERVICE_NAME}.service"
                    sudo rm -f "/etc/systemd/system/${CLIENT_SERVICE_NAME}.service"
                    sudo systemctl daemon-reload
                    sudo rm -f "${CLIENT_TARGET_DIR}/${CLIENT_BINARY_NAME}"
                    echo -e "${GREEN}✓ 节点/客户端已卸载${NC}"
                    send_statistics "uninstall" "client"
                else
                    echo -e "${BLUE}▶ 卸载已取消${NC}"
                fi
                sleep 2
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}✗ 无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 主菜单
main_menu() {
    # 首次运行安装工具箱服务
    if [ ! -f "/usr/local/bin/${SCRIPT_NAME}" ]; then
        print_header
        echo -e "${GREEN}▶ 首次运行工具箱，正在安装...${NC}"
        install_toolbox_service
        send_statistics "first_run" "toolbox"
    fi
    
    while true; do
        print_header
        echo -e "${BLUE}请选择操作类型:${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理${NC}"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理${NC}"
        echo -e "${CYAN}3. ${WHITE}检查脚本更新${NC}"
        echo -e "${CYAN}4. ${WHITE}查看更新日志${NC}"
        echo -e "${CYAN}0. ${WHITE}退出工具箱${NC}"
        echo ""
        
        read -rp "请输入选项编号 (0-4): " choice
        
        case $choice in
            1)
                manage_server
                ;;
            2)
                manage_client
                ;;
            3)
                update_script
                ;;
            4)
                print_header
                echo -e "${YELLOW}════════════ 更新日志 v${SCRIPT_VERSION} ════════════${NC}"
                echo -e "${WHITE}2024-06-15 v1.0${NC}"
                echo -e "${CYAN}- 初始版本发布${NC}"
                echo -e "${CYAN}- 整合服务端和节点/客户端管理功能${NC}"
                echo -e "${CYAN}- 添加自动更新和统计功能${NC}"
                echo -e "${YELLOW}════════════════════════════════════════════${NC}"
                echo ""
                read -n 1 -s -r -p "$(echo -e "${BLUE}按任意键返回...${NC}")"
                ;;
            0)
                echo -e "${BLUE}▶ 感谢使用 GOSTC 工具箱${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}✗ 无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
