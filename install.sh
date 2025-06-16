#!/bin/bash

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 工具箱版本和更新日志
TOOL_VERSION="1.6.0"
CHANGELOG="
版本 $TOOL_VERSION 更新日志:
----------------------------------------
1. 在所有菜单中添加服务状态显示
2. 优化状态检测逻辑
3. 添加服务未安装状态显示
4. 改进用户界面布局
"

# 安装路径
TOOL_PATH="/usr/local/bin/gotool"

# 检查是否通过管道安装
if [[ "$0" == "-" ]] || [[ "$0" == "bash" ]]; then
    echo -e "${GREEN}▶ 正在安装工具箱到 ${TOOL_PATH}${NC}"
    sudo curl -fL -o "$TOOL_PATH" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh" || {
        echo -e "${RED}✗ 下载安装脚本失败!${NC}"
        exit 1
    }
    sudo chmod +x "$TOOL_PATH"
    echo -e "${GREEN}✓ 工具箱安装完成! 请使用 'gotool' 命令运行工具箱${NC}"
    exit 0
fi

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误：此脚本必须使用 root 权限运行。请使用 'sudo $0' 或切换至 root 用户执行。${NC}"
    exit 1
fi

# 获取系统架构函数
get_architecture() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
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
        "riscv64") FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x")   FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}"
            return 1
            ;;
    esac
    
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    echo "${OS}_${FILE_SUFFIX}"
}

# 验证服务器连接 (WS/WSS)
validate_server_ws() {
    local address=$1
    local use_tls=$2
    
    # 构造WS/WSS URL
    if [[ "$use_tls" == "true" ]]; then
        if [[ "$address" != wss:* ]]; then
            address="wss://$address"
        fi
    else
        if [[ "$address" != ws:* ]]; then
            address="ws://$address"
        fi
    fi
    
    # 使用curl尝试连接WebSocket
    echo -e "${BLUE}▷ 验证服务器连接: ${WHITE}$address${NC}"
    
    # 尝试建立WebSocket连接 (超时3秒)
    if curl -s -I -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" \
       --connect-timeout 3 "$address" 2>&1 | grep -q "101 Switching Protocols"; then
        echo -e "${GREEN}✓ 服务器连接成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 无法建立WebSocket连接${NC}"
        return 1
    fi
}

# 检查服务状态函数
check_service_status() {
    local service_name=$1
    local binary_path=$2
    
    # 检查服务是否安装
    if [ ! -f "$binary_path" ]; then
        echo -e "${YELLOW}[未安装]${NC}"
        return
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}[运行中]${NC}"
    elif systemctl is-failed --quiet "$service_name"; then
        echo -e "${RED}[失败]${NC}"
    else
        echo -e "${YELLOW}[未运行]${NC}"
    fi
}

# 服务端管理函数
server_management() {
    while true; do
        clear
        # 获取服务状态
        SERVER_STATUS=$(check_service_status "gostc-admin" "/usr/local/gostc-admin/server")
        
        echo -e "${PURPLE}================================${NC}"
        echo -e "${WHITE}  GOSTC 服务端管理 ${SERVER_STATUS} ${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo -e "${GREEN}1. 安装/更新服务端${NC}"
        echo -e "${GREEN}2. 启动服务${NC}"
        echo -e "${GREEN}3. 停止服务${NC}"
        echo -e "${GREEN}4. 重启服务${NC}"
        echo -e "${GREEN}5. 卸载服务端${NC}"
        echo -e "${YELLOW}0. 返回主菜单${NC}"
        echo -e "${PURPLE}================================${NC}"
        
        read -rp "请输入选项编号: " server_choice
        
        case $server_choice in
            1) install_server ;;
            2) start_server ;;
            3) stop_server ;;
            4) restart_server ;;
            5) uninstall_server ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}"; sleep 1 ;;
        esac
    done
}

# 节点/客户端管理函数
client_management() {
    while true; do
        clear
        # 获取服务状态
        CLIENT_STATUS=$(check_service_status "gostc" "/usr/local/bin/gostc")
        
        echo -e "${BLUE}================================${NC}"
        echo -e "${WHITE}  GOSTC 节点/客户端管理 ${CLIENT_STATUS} ${NC}"
        echo -e "${BLUE}================================${NC}"
        echo -e "${GREEN}1. 安装节点${NC}"
        echo -e "${GREEN}2. 安装客户端${NC}"
        echo -e "${GREEN}3. 启动服务${NC}"
        echo -e "${GREEN}4. 停止服务${NC}"
        echo -e "${GREEN}5. 重启服务${NC}"
        echo -e "${GREEN}6. 卸载服务${NC}"
        echo -e "${YELLOW}0. 返回主菜单${NC}"
        echo -e "${BLUE}================================${NC}"
        
        read -rp "请输入选项编号: " client_choice
        
        case $client_choice in
            1) install_node ;;
            2) install_client ;;
            3) start_client ;;
            4) stop_client ;;
            5) restart_client ;;
            6) uninstall_client ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}"; sleep 1 ;;
        esac
    done
}

# 安装服务端
install_server() {
    clear
    echo -e "${PURPLE}========================${NC}"
    echo -e "${WHITE}  GOSTC 服务端安装向导 ${NC}"
    echo -e "${PURPLE}========================${NC}"

    # 配置参数
    TARGET_DIR="/usr/local/gostc-admin"
    BINARY_NAME="server"
    SERVICE_NAME="gostc-admin"
    CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    # 检查是否已安装
    if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}3. ${WHITE}返回${NC}"
        echo ""
        
        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                return
                ;;
            *)
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
    
    # 获取系统架构
    ARCH_INFO=$(get_architecture)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    OS_TYPE=$(echo "$ARCH_INFO" | cut -d'_' -f1)
    FILE_SUFFIX=$(echo "$ARCH_INFO" | cut -d'_' -f2-)
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS_TYPE} ${FILE_SUFFIX}${NC}"
    
    # 构建下载URL
    FILE_NAME="server_${OS_TYPE}_${FILE_SUFFIX}"
    [ "$OS_TYPE" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        exit 1
    }
    
    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$CONFIG_FILE" "${CONFIG_FILE}.bak" 2>/dev/null
        
        # 删除旧文件但保留配置文件
        sudo find "${TARGET_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        
        # 恢复配置文件
        sudo mv -f "${CONFIG_FILE}.bak" "$CONFIG_FILE" 2>/dev/null
    else
        # 全新安装模式
        sudo rm -f "$TARGET_DIR/$BINARY_NAME"  # 清理旧版本
    fi
    
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        exit 1
    fi
    
    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        exit 1
    fi
    
    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install
    fi
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVICE_NAME"
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVICE_NAME}${NC}"
    fi
    
    # 安装完成提示
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}${INSTALL_MODE:-安装}完成${PURPLE}                   ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  操作类型: ${WHITE}$([ "$UPDATE_MODE" = true ] && echo "更新" || echo "${INSTALL_MODE:-安装}")${PURPLE}                     ║"
    echo -e "║  版本: ${WHITE}${VERSION_NAME}${PURPLE}                             ║"
    echo -e "║  安装目录: ${WHITE}$TARGET_DIR${PURPLE}                     ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)                          ║"
    echo -e "║  访问地址: ${WHITE}http://localhost:8080${PURPLE}             ║"
    echo -e "║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${PURPLE} ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 显示初始凭据
    if [ ! -f "$CONFIG_FILE" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
    
    read -rp "按回车键返回..."
}

# 启动服务端
start_server() {
    TARGET_DIR="/usr/local/gostc-admin"
    BINARY_NAME="server"
    SERVICE_NAME="gostc-admin"
    
    if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl start "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${RED}✗ 服务启动失败!${NC}"
    fi
    sleep 2
}

# 停止服务端
stop_server() {
    SERVICE_NAME="gostc-admin"
    
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}服务未运行${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl stop "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "inactive" ]; then
        echo -e "${GREEN}✓ 服务已停止${NC}"
    else
        echo -e "${RED}✗ 服务停止失败!${NC}"
    fi
    sleep 2
}

# 重启服务端
restart_server() {
    SERVICE_NAME="gostc-admin"
    
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}服务未运行${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl restart "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败!${NC}"
    fi
    sleep 2
}

# 卸载服务端
uninstall_server() {
    TARGET_DIR="/usr/local/gostc-admin"
    BINARY_NAME="server"
    SERVICE_NAME="gostc-admin"
    
    if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        sleep 2
        return
    fi
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 卸载服务
    if sudo systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        sudo "${TARGET_DIR}/${BINARY_NAME}" service uninstall
    fi
    
    # 删除文件
    sudo rm -rf "$TARGET_DIR"
    
    echo -e "${GREEN}✓ 服务端已成功卸载${NC}"
    sleep 2
}

# 安装节点
install_node() {
    clear
    echo -e "${BLUE}========================${NC}"
    echo -e "${WHITE}  GOSTC 节点安装向导 ${NC}"
    echo -e "${BLUE}========================${NC}"
    
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    # 安装二进制文件
    echo -e "${BLUE}▶ 开始安装节点组件${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 获取系统架构
    ARCH_INFO=$(get_architecture)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    OS_TYPE=$(echo "$ARCH_INFO" | cut -d'_' -f1)
    FILE_SUFFIX=$(echo "$ARCH_INFO" | cut -d'_' -f2-)
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS_TYPE} ${FILE_SUFFIX}${NC}"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS_TYPE}_${FILE_SUFFIX}"
    [ "$OS_TYPE" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        exit 1
    }
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo rm -f "$TARGET_DIR/$BINARY_NAME"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        exit 1
    fi
    
    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        exit 1
    fi
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 节点配置
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
        
        if validate_server_ws "$input_addr" "$use_tls"; then
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
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置节点${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        exit 1
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}节点安装成功${BLUE}                  ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}节点${BLUE}                                   ║"
    echo -e "║  安装目录: ${WHITE}$TARGET_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url${BLUE}               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -rp "按回车键返回..."
}

# 安装客户端
install_client() {
    clear
    echo -e "${BLUE}========================${NC}"
    echo -e "${WHITE}  GOSTC 客户端安装向导 ${NC}"
    echo -e "${BLUE}========================${NC}"
    
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    # 安装二进制文件
    echo -e "${BLUE}▶ 开始安装客户端组件${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 获取系统架构
    ARCH_INFO=$(get_architecture)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    OS_TYPE=$(echo "$ARCH_INFO" | cut -d'_' -f1)
    FILE_SUFFIX=$(echo "$ARCH_INFO" | cut -d'_' -f2-)
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS_TYPE} ${FILE_SUFFIX}${NC}"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS_TYPE}_${FILE_SUFFIX}"
    [ "$OS_TYPE" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        exit 1
    }
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo rm -f "$TARGET_DIR/$BINARY_NAME"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        exit 1
    fi
    
    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        exit 1
    fi
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 客户端配置
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
        
        if validate_server_ws "$input_addr" "$use_tls"; then
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
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        exit 1
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}客户端安装成功${BLUE}                ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}客户端${BLUE}                                 ║"
    echo -e "║  安装目录: ${WHITE}$TARGET_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -rp "按回车键返回..."
}

# 启动客户端/节点
start_client() {
    SERVICE_NAME="gostc"
    
    if ! command -v gostc &> /dev/null; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl start "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${RED}✗ 服务启动失败!${NC}"
    fi
    sleep 2
}

# 停止客户端/节点
stop_client() {
    SERVICE_NAME="gostc"
    
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}服务未运行${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl stop "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "inactive" ]; then
        echo -e "${GREEN}✓ 服务已停止${NC}"
    else
        echo -e "${RED}✗ 服务停止失败!${NC}"
    fi
    sleep 2
}

# 重启客户端/节点
restart_client() {
    SERVICE_NAME="gostc"
    
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}服务未运行${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl restart "$SERVICE_NAME"
    sleep 1
    
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败!${NC}"
    fi
    sleep 2
}

# 卸载客户端/节点
uninstall_client() {
    SERVICE_NAME="gostc"
    
    if ! command -v gostc &> /dev/null; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        sleep 2
        return
    fi
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 卸载服务
    if sudo systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        sudo gostc uninstall
    fi
    
    # 删除文件
    sudo rm -f /usr/local/bin/gostc
    
    echo -e "${GREEN}✓ 客户端/节点已成功卸载${NC}"
    sleep 2
}

# 更新工具箱
update_toolbox() {
    echo -e "${YELLOW}▶ 正在检查更新...${NC}"
    
    # 获取最新版本
    LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/dxiaom/gotool/main/version.txt")
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}✗ 无法获取最新版本信息${NC}"
        sleep 2
        return
    fi
    
    if [ "$LATEST_VERSION" = "$TOOL_VERSION" ]; then
        echo -e "${GREEN}✓ 当前已是最新版本 (v$TOOL_VERSION)${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BLUE}发现新版本: v${LATEST_VERSION}${NC}"
    echo -e "${YELLOW}更新日志:${NC}"
    echo -e "${CHANGELOG}"
    
    read -rp "是否要更新到 v${LATEST_VERSION}? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
        sudo curl -fL -o "$TOOL_PATH" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh" || {
            echo -e "${RED}✗ 更新失败!${NC}"
            sleep 2
            return
        }
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已成功更新到 v${LATEST_VERSION}${NC}"
        echo -e "${YELLOW}请重新运行 'gotool' 以使用新版本${NC}"
        exit 0
    fi
}

# 卸载工具箱
uninstall_toolbox() {
    read -rp "确定要卸载工具箱? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo rm -f "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已成功卸载${NC}"
        exit 0
    fi
    echo -e "${YELLOW}卸载已取消${NC}"
    sleep 1
}

# 主菜单
main_menu() {
    while true; do
        clear
        # 获取服务状态
        SERVER_STATUS=$(check_service_status "gostc-admin" "/usr/local/gostc-admin/server")
        CLIENT_STATUS=$(check_service_status "gostc" "/usr/local/bin/gostc")
        
        echo -e "${CYAN}================================${NC}"
        echo -e "${WHITE}   GOSTC 服务管理工具箱 v${TOOL_VERSION}   ${NC}"
        echo -e "${CYAN}================================${NC}"
        echo -e "${GREEN}1. 服务端管理 ${SERVER_STATUS}${NC}"
        echo -e "${GREEN}2. 节点/客户端管理 ${CLIENT_STATUS}${NC}"
        echo -e "${BLUE}3. 更新工具箱${NC}"
        echo -e "${RED}4. 卸载工具箱${NC}"
        echo -e "${YELLOW}0. 退出${NC}"
        echo -e "${CYAN}================================${NC}"
        
        read -rp "请输入选项编号: " main_choice
        
        case $main_choice in
            1) server_management ;;
            2) client_management ;;
            3) update_toolbox ;;
            4) uninstall_toolbox ;;
            0)
                echo -e "${BLUE}感谢使用，再见!${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选择!${NC}"; sleep 1 ;;
        esac
    done
}

# 首次运行提示
if [ ! -f ~/.gotool_installed ]; then
    clear
    echo -e "${GREEN}================================${NC}"
    echo -e "${WHITE}   GOSTC 服务管理工具箱已安装   ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "感谢您安装 GOSTC 服务管理工具箱!"
    echo -e "此工具提供以下功能:"
    echo -e "  - 服务端安装、配置和管理"
    echo -e "  - 节点/客户端安装、配置和管理"
    echo -e "  - 工具箱自身更新和卸载"
    echo -e ""
    echo -e "使用命令: ${CYAN}gotool${NC} 来运行工具箱"
    echo -e "${GREEN}================================${NC}"
    touch ~/.gotool_installed
    sleep 3
fi

# 启动主菜单
main_menu
