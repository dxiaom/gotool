#!/bin/bash

# 工具箱版本号
TOOL_VERSION="1.1.1"
UPDATE_LOG="
版本 1.1.1 更新日志：
  - 优化了架构检测函数
  - 增强了错误处理
  - 改进了用户提示信息
  - 修复了已知问题

版本 1.1.0 更新日志：
  - 初始版本发布
  - 支持服务端和节点/客户端的安装管理
  - 添加工具箱自动更新功能
"

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 工具箱安装路径
TOOL_PATH="/usr/local/bin/gotool"

# 函数: 获取系统信息
get_system_info() {
    local OS ARCH
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 架构检测
    local FILE_SUFFIX=""
    case "$ARCH" in
        "x86_64")
            FILE_SUFFIX="amd64_v1"
            [ "$OS" = "linux" ] && {
                if grep -q "avx512" /proc/cpuinfo 2>/dev/null; then
                    FILE_SUFFIX="amd64_v3"
                elif grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
                    FILE_SUFFIX="amd64_v1"
                fi
            }
            ;;
        "i"*"86")          FILE_SUFFIX="386_sse2" ;;
        "aarch64"|"arm64") FILE_SUFFIX="arm64_v8.0" ;;
        "armv7l")          FILE_SUFFIX="arm_7" ;;
        "armv6l")          FILE_SUFFIX="arm_6" ;;
        "armv5l")          FILE_SUFFIX="arm_5" ;;
        "mips64")
            if lscpu 2>/dev/null | grep -qi "little endian"; then
                FILE_SUFFIX="mips64le_hardfloat"
            else
                FILE_SUFFIX="mips64_hardfloat"
            fi
            ;;
        "mips")
            if lscpu 2>/dev/null | grep -qi "FPU"; then
                FLOAT="hardfloat"
            else
                FLOAT="softfloat"
            fi
            if lscpu 2>/dev/null | grep -qi "little endian"; then
                FILE_SUFFIX="mipsle_$FLOAT"
            else
                FILE_SUFFIX="mips_$FLOAT"
            fi
            ;;
        "riscv64")         FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x")           FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}" >&2
            return 1
            ;;
    esac
    
    echo "$OS $FILE_SUFFIX"
}

# 函数: 验证服务器地址 (使用WS/WSS)
validate_server_address() {
    local address=$1
    local use_tls=$2
    
    # 添加协议前缀
    if [[ "$use_tls" == "true" ]]; then
        if [[ "$address" != wss:* ]]; then
            address="wss://${address#*://}"
        fi
    else
        if [[ "$address" != ws:* ]]; then
            address="ws://${address#*://}"
        fi
    fi
    
    # 验证服务器是否可达
    echo -e "${BLUE}▷ 验证服务器地址: ${WHITE}$address${NC}"
    
    # 使用curl检查WebSocket连接
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        --connect-timeout 5 "$address")
    
    if [[ "$status_code" =~ ^(101|200|301|302|307)$ ]]; then
        echo -e "${GREEN}✓ 服务器验证成功 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 函数: 检查服务状态
check_service_status() {
    local service_name=$1
    
    if ! command -v systemctl &> /dev/null; then
        echo "unknown"
        return
    fi
    
    if sudo systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo "active"
    elif sudo systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        echo "inactive"
    else
        echo "not-installed"
    fi
}

# 函数: 显示服务状态
display_status() {
    local status=$1
    
    case "$status" in
        "active")
            echo -e "${GREEN}[运行中]${NC}"
            ;;
        "inactive")
            echo -e "${YELLOW}[未运行]${NC}"
            ;;
        "failed")
            echo -e "${RED}[失败]${NC}"
            ;;
        "not-installed")
            echo -e "${YELLOW}[未安装]${NC}"
            ;;
        *)
            echo -e "${YELLOW}[未知]${NC}"
            ;;
    esac
}

# 函数: 安装工具箱
install_toolbox() {
    echo -e "${GREEN}▶ 正在安装GOSTC工具箱${NC}"
    
    # 下载最新版本
    echo -e "${BLUE}▷ 下载工具箱脚本...${NC}"
    if ! curl -sSfL -o "$TOOL_PATH" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"; then
        echo -e "${RED}✗ 下载工具箱失败${NC}" >&2
        exit 1
    fi
    
    # 设置权限
    chmod +x "$TOOL_PATH"
    
    echo -e "${GREEN}✓ 工具箱安装成功${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}请使用以下命令运行工具箱:${NC}"
    echo -e "  ${PURPLE}gotool${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    exit 0
}

# 函数: 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 确定要卸载GOSTC工具箱吗？${NC}"
    read -p "$(echo -e "${BLUE}▷ 请输入确认 (y/n): ${NC}")" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已卸载${NC}"
    else
        echo -e "${BLUE}▶ 卸载已取消${NC}"
    fi
    exit 0
}

# 函数: 检查更新
check_updates() {
    echo -e "${BLUE}▶ 检查工具箱更新...${NC}"
    
    # 获取最新版本
    local latest_version
    latest_version=$(curl -sSfL "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh" | 
        grep -m1 'TOOL_VERSION=' | 
        cut -d'"' -f2)
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}✗ 无法获取最新版本信息${NC}" >&2
        return 1
    fi
    
    if [[ "$TOOL_VERSION" == "$latest_version" ]]; then
        echo -e "${GREEN}✓ 当前已是最新版本 (v$TOOL_VERSION)${NC}"
    else
        echo -e "${YELLOW}▶ 发现新版本: v$latest_version${NC}"
        echo -e "${CYAN}════════════════ 更新日志 ══════════════════${NC}"
        
        # 获取更新日志
        local latest_log
        latest_log=$(curl -sSfL "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh" | 
            sed -n '/UPDATE_LOG="/,/^"/p' | 
            sed '1s/UPDATE_LOG="//;$s/"$//')
            
        echo -e "${latest_log:-$UPDATE_LOG}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        
        read -p "$(echo -e "${BLUE}▷ 是否更新到最新版本? (y/n): ${NC}")" confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            install_toolbox
        fi
    fi
}

# 函数: 下载并解压文件
download_and_extract() {
    local download_url=$1
    local target_dir=$2
    local binary_name=$3
    
    # 获取文件名
    local file_name
    file_name=$(basename "$download_url")
    
    # 下载文件
    echo -e "${BLUE}▷ 下载文件...${NC}"
    if ! curl -# -fL -o "$file_name" "$download_url"; then
        echo -e "${RED}✗ 文件下载失败: $download_url${NC}" >&2
        return 1
    fi
    
    # 解压文件
    echo -e "${BLUE}▷ 解压文件...${NC}"
    local extract_cmd
    case "$file_name" in
        *.zip)
            extract_cmd="unzip -qo '$file_name' -d '$target_dir'"
            ;;
        *.tar.gz)
            extract_cmd="tar xzf '$file_name' -C '$target_dir'"
            ;;
        *)
            echo -e "${RED}✗ 不支持的文件格式: $file_name${NC}" >&2
            rm -f "$file_name"
            return 1
            ;;
    esac
    
    if ! eval "$extract_cmd"; then
        echo -e "${RED}✗ 文件解压失败${NC}" >&2
        rm -f "$file_name"
        return 1
    fi
    
    # 设置权限
    if [[ -f "${target_dir}/${binary_name}" ]]; then
        chmod 755 "${target_dir}/${binary_name}"
        echo -e "${GREEN}✓ 已安装二进制文件: ${target_dir}/${binary_name}${NC}"
    else
        echo -e "${RED}✗ 解压后未找到二进制文件: $binary_name${NC}" >&2
        return 1
    fi
    
    # 清理临时文件
    rm -f "$file_name"
    return 0
}

# 函数: 服务端管理菜单
server_menu() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    local CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    while true; do
        # 获取服务状态
        local server_status
        server_status=$(check_service_status "$SERVICE_NAME")
        
        clear
        echo -e "${PURPLE}"
        echo "══════════════════════════════════════════════════"
        echo -e "        ${WHITE}GOSTC 服务端管理${PURPLE} $(display_status "$server_status")"
        echo "══════════════════════════════════════════════════"
        echo -e "${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端"
        echo -e "${CYAN}2. ${WHITE}启动服务端"
        echo -e "${CYAN}3. ${WHITE}停止服务端"
        echo -e "${CYAN}4. ${WHITE}重启服务端"
        echo -e "${CYAN}5. ${WHITE}卸载服务端"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -p "$(echo -e "${BLUE}▷ 请选择操作: ${NC}")" server_choice
        
        case $server_choice in
            1) install_server ;;
            2) start_server ;;
            3) stop_server ;;
            4) restart_server ;;
            5) uninstall_server ;;
            0) return ;;
            *) 
                echo -e "${RED}✗ 无效选择${NC}"
                sleep 1 
                ;;
        esac
    done
}

# 函数: 安装服务端
install_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    local CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    clear
    echo -e "${PURPLE}"
    echo "══════════════════════════════════════════════════"
    echo -e "          ${WHITE}GOSTC 服务端安装向导${PURPLE}"
    echo "══════════════════════════════════════════════════"
    echo -e "${NC}"
    
    # 检查是否已安装
    local UPDATE_MODE=false
    local INSTALL_MODE="安装"
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本 (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本 (删除所有文件重新安装)"
        echo -e "${CYAN}3. ${WHITE}退出${NC}"
        echo ""

        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "${operation_choice:-1}" in
            2)
                # 完全重新安装
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${TARGET_DIR}"
                INSTALL_MODE="重新安装"
                ;;
            3)
                echo -e "${BLUE}操作已取消${NC}"
                return
                ;;
            *)
                # 更新操作
                echo -e "${YELLOW}▶ 开始更新服务端到最新版本...${NC}"
                UPDATE_MODE=true
                INSTALL_MODE="更新"
                ;;
        esac
        echo ""
    fi

    # 选择版本
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "${CYAN}1. ${WHITE}普通版本 (默认)"
    echo -e "${CYAN}2. ${WHITE}商业版本 (需要授权)"
    echo -e "${NC}"

    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice

    # 设置下载URL
    local BASE_URL VERSION_NAME
    case "${version_choice:-1}" in
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
    local system_info
    system_info=$(get_system_info)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local OS FILE_SUFFIX
    OS=$(echo "$system_info" | awk '{print $1}')
    FILE_SUFFIX=$(echo "$system_info" | awk '{print $2}')
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS}${NC}"

    # 构建下载URL
    local FILE_NAME DOWNLOAD_URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [[ "$OS" == "windows" ]] && 
        FILE_NAME="${FILE_NAME}.zip" || 
        FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME" || {
            echo -e "${RED}✗ 停止服务失败${NC}" >&2
            return 1
        }
    fi

    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1

    # 下载并解压
    if ! download_and_extract "$DOWNLOAD_URL" "$TARGET_DIR" "$BINARY_NAME"; then
        return 1
    fi

    # 更新模式：保留配置文件
    if [[ "$UPDATE_MODE" == true && -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}▷ 备份配置文件...${NC}"
        sudo cp -f "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        if ! sudo "$TARGET_DIR/$BINARY_NAME" service install; then
            echo -e "${RED}✗ 服务安装失败${NC}" >&2
            return 1
        fi
    fi

    # 恢复配置文件
    if [[ "$UPDATE_MODE" == true && -f "${CONFIG_FILE}.bak" ]]; then
        echo -e "${YELLOW}▷ 恢复配置文件...${NC}"
        sudo mv -f "${CONFIG_FILE}.bak" "$CONFIG_FILE"
    fi

    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    if ! sudo systemctl restart "$SERVICE_NAME"; then
        echo -e "${YELLOW}⚠ 服务启动失败，尝试重新启动...${NC}"
        sleep 2
        sudo systemctl restart "$SERVICE_NAME" || {
            echo -e "${RED}✗ 服务启动失败${NC}" >&2
        }
    fi

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    local SERVICE_STATUS
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [[ "$SERVICE_STATUS" == "active" ]]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVICE_NAME}${NC}"
    fi

    # 安装完成提示
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════"
    echo -e "                   ${WHITE}${INSTALL_MODE}完成${PURPLE}                   "
    echo -e "══════════════════════════════════════════════════"
    echo -e "  操作类型: ${WHITE}${INSTALL_MODE}${PURPLE}"
    echo -e "  版本: ${WHITE}${VERSION_NAME}${PURPLE}"
    echo -e "  安装目录: ${WHITE}$TARGET_DIR${PURPLE}"
    echo -e "══════════════════════════════════════════════════"
    echo -e "  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)"
    echo -e "  访问地址: ${WHITE}http://localhost:8080${PURPLE}"
    echo -e "  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${PURPLE}"
    echo -e "══════════════════════════════════════════════════"
    echo -e "${NC}"

    # 显示初始凭据（仅在新安装或重新安装时显示）
    if [[ "$INSTALL_MODE" != "更新" && ! -f "$CONFIG_FILE" ]]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}▷ 按任意键继续...${NC}")"
}

# 函数: 启动服务端
start_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    echo -e "${BLUE}▶ 启动服务端...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务端未安装，请先安装${NC}"
        return 1
    fi
    
    if sudo systemctl start "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" == "active" ]]; then
            echo -e "${GREEN}✓ 服务端已成功启动${NC}"
        else
            echo -e "${YELLOW}⚠ 服务端状态: ${SERVICE_STATUS}${NC}"
        fi
    else
        echo -e "${RED}✗ 服务端启动失败${NC}"
    fi
    
    sleep 1
}

# 函数: 停止服务端
stop_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    echo -e "${BLUE}▶ 停止服务端...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务端未安装${NC}"
        return 1
    fi
    
    if sudo systemctl stop "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" != "active" ]]; then
            echo -e "${GREEN}✓ 服务端已停止${NC}"
        else
            echo -e "${YELLOW}⚠ 服务端仍在运行${NC}"
        fi
    else
        echo -e "${RED}✗ 服务端停止失败${NC}"
    fi
    
    sleep 1
}

# 函数: 重启服务端
restart_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    echo -e "${BLUE}▶ 重启服务端...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务端未安装${NC}"
        return 1
    fi
    
    if sudo systemctl restart "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" == "active" ]]; then
            echo -e "${GREEN}✓ 服务端已成功重启${NC}"
        else
            echo -e "${YELLOW}⚠ 服务端状态: ${SERVICE_STATUS}${NC}"
        fi
    else
        echo -e "${RED}✗ 服务端重启失败${NC}"
    fi
    
    sleep 1
}

# 函数: 卸载服务端
uninstall_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    echo -e "${YELLOW}▶ 确定要卸载服务端吗？${NC}"
    read -p "$(echo -e "${BLUE}▷ 请输入确认 (y/n): ${NC}")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}▶ 卸载已取消${NC}"
        return 0
    fi
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 禁用服务
    if sudo systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 禁用服务...${NC}"
        sudo systemctl disable "$SERVICE_NAME"
    fi
    
    # 卸载服务
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${YELLOW}▷ 卸载服务...${NC}"
        sudo "${TARGET_DIR}/${BINARY_NAME}" service uninstall
    fi
    
    # 删除文件
    echo -e "${YELLOW}▷ 删除文件...${NC}"
    sudo rm -rf "$TARGET_DIR"
    
    # 删除服务文件
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ 服务端已卸载${NC}"
    sleep 1
}

# 函数: 安装节点
install_node() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    # 配置提示
    clear
    echo -e "${BLUE}"
    echo "══════════════════════════════════════════════════"
    echo -e "          ${WHITE}GOSTC 节点安装向导${BLUE}"
    echo "══════════════════════════════════════════════════"
    echo -e "${NC}"
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
        input_addr=${input_addr:-$server_addr}
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
        fi
    done
    
    # 节点密钥
    local node_key=""
    while [[ -z "$node_key" ]]; do
        read -p "$(echo -e "${BLUE}▷ 输入节点密钥: ${NC}")" node_key
        if [[ -z "$node_key" ]]; then
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
    
    # 安装组件
    if ! install_component "节点"; then
        return 1
    fi
    
    # 构建安装命令
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    
    if [[ -n "$proxy_base_url" ]]; then
        install_cmd+=" --proxy-base-url $proxy_base_url"
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置节点${NC}"
    
    # 执行安装命令
    if ! eval "$install_cmd"; then
        echo -e "${RED}✗ 节点配置失败${NC}" >&2
        return 1
    fi
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}" >&2
        return 1
    fi
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════"
    echo -e "                   ${WHITE}节点安装成功${BLUE}                  "
    echo -e "══════════════════════════════════════════════════"
    echo -e "  组件: ${WHITE}节点${BLUE}"
    echo -e "  安装目录: ${WHITE}$TARGET_DIR${BLUE}"
    echo -e "  服务器地址: ${WHITE}$server_addr${BLUE}"
    echo -e "  TLS: ${WHITE}$use_tls${BLUE}"
    if [[ -n "$proxy_base_url" ]]; then
        echo -e "  网关地址: ${WHITE}$proxy_base_url${BLUE}"
    fi
    echo -e "══════════════════════════════════════════════════"
    echo -e "${NC}"
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}▷ 按任意键继续...${NC}")"
}

# 函数: 安装客户端
install_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    # 配置提示
    clear
    echo -e "${BLUE}"
    echo "══════════════════════════════════════════════════"
    echo -e "          ${WHITE}GOSTC 客户端安装向导${BLUE}"
    echo "══════════════════════════════════════════════════"
    echo -e "${NC}"
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
        input_addr=${input_addr:-$server_addr}
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
        fi
    done
    
    # 客户端密钥
    local client_key=""
    while [[ -z "$client_key" ]]; do
        read -p "$(echo -e "${BLUE}▷ 输入客户端密钥: ${NC}")" client_key
        if [[ -z "$client_key" ]]; then
            echo -e "${RED}✗ 客户端密钥不能为空${NC}"
        fi
    done
    
    # 安装组件
    if ! install_component "客户端"; then
        return 1
    fi
    
    # 构建安装命令
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    if ! eval "$install_cmd"; then
        echo -e "${RED}✗ 客户端配置失败${NC}" >&2
        return 1
    fi
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}" >&2
        return 1
    fi
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════"
    echo -e "                   ${WHITE}客户端安装成功${BLUE}                "
    echo -e "══════════════════════════════════════════════════"
    echo -e "  组件: ${WHITE}客户端${BLUE}"
    echo -e "  安装目录: ${WHITE}$TARGET_DIR${BLUE}"
    echo -e "  服务器地址: ${WHITE}$server_addr${BLUE}"
    echo -e "  TLS: ${WHITE}$use_tls${BLUE}"
    echo -e "══════════════════════════════════════════════════"
    echo -e "${NC}"
    
    read -n 1 -s -r -p "$(echo -e "${BLUE}▷ 按任意键继续...${NC}")"
}

# 函数: 节点/客户端管理菜单
client_menu() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    while true; do
        # 获取服务状态
        local client_status
        client_status=$(check_service_status "$SERVICE_NAME")
        
        clear
        echo -e "${PURPLE}"
        echo "══════════════════════════════════════════════════"
        echo -e "        ${WHITE}GOSTC 节点/客户端管理${PURPLE} $(display_status "$client_status")"
        echo "══════════════════════════════════════════════════"
        echo -e "${NC}"
        echo -e "${CYAN}1. ${WHITE}安装节点"
        echo -e "${CYAN}2. ${WHITE}安装客户端"
        echo -e "${CYAN}3. ${WHITE}启动服务"
        echo -e "${CYAN}4. ${WHITE}停止服务"
        echo -e "${CYAN}5. ${WHITE}重启服务"
        echo -e "${CYAN}6. ${WHITE}卸载服务"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -p "$(echo -e "${BLUE}▷ 请选择操作: ${NC}")" client_choice
        
        case $client_choice in
            1) install_node ;;
            2) install_client ;;
            3) start_client ;;
            4) stop_client ;;
            5) restart_client ;;
            6) uninstall_client ;;
            0) return ;;
            *) 
                echo -e "${RED}✗ 无效选择${NC}"
                sleep 1 
                ;;
        esac
    done
}

# 函数: 启动节点/客户端
start_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    echo -e "${BLUE}▶ 启动服务...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务未安装，请先安装${NC}"
        return 1
    fi
    
    if sudo systemctl start "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" == "active" ]]; then
            echo -e "${GREEN}✓ 服务已成功启动${NC}"
        else
            echo -e "${YELLOW}⚠ 服务状态: ${SERVICE_STATUS}${NC}"
        fi
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
    fi
    
    sleep 1
}

# 函数: 停止节点/客户端
stop_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    echo -e "${BLUE}▶ 停止服务...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务未安装${NC}"
        return 1
    fi
    
    if sudo systemctl stop "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" != "active" ]]; then
            echo -e "${GREEN}✓ 服务已停止${NC}"
        else
            echo -e "${YELLOW}⚠ 服务仍在运行${NC}"
        fi
    else
        echo -e "${RED}✗ 服务停止失败${NC}"
    fi
    
    sleep 1
}

# 函数: 重启节点/客户端
restart_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    echo -e "${BLUE}▶ 重启服务...${NC}"
    
    if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${RED}✗ 服务未安装${NC}"
        return 1
    fi
    
    if sudo systemctl restart "$SERVICE_NAME"; then
        sleep 1
        local SERVICE_STATUS
        SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
        if [[ "$SERVICE_STATUS" == "active" ]]; then
            echo -e "${GREEN}✓ 服务已成功重启${NC}"
        else
            echo -e "${YELLOW}⚠ 服务状态: ${SERVICE_STATUS}${NC}"
        fi
    else
        echo -e "${RED}✗ 服务重启失败${NC}"
    fi
    
    sleep 1
}

# 函数: 卸载节点/客户端
uninstall_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    echo -e "${YELLOW}▶ 确定要卸载服务吗？${NC}"
    read -p "$(echo -e "${BLUE}▷ 请输入确认 (y/n): ${NC}")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}▶ 卸载已取消${NC}"
        return 0
    fi
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 禁用服务
    if sudo systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 禁用服务...${NC}"
        sudo systemctl disable "$SERVICE_NAME"
    fi
    
    # 卸载服务
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${YELLOW}▷ 卸载服务...${NC}"
        sudo "${TARGET_DIR}/${BINARY_NAME}" uninstall
    fi
    
    # 删除文件
    echo -e "${YELLOW}▷ 删除文件...${NC}"
    sudo rm -f "${TARGET_DIR}/${BINARY_NAME}"
    
    # 删除服务文件
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ 服务已卸载${NC}"
    sleep 1
}

# 函数: 主菜单
main_menu() {
    # 检查是否通过管道安装
    if [[ ! -t 0 ]]; then
        install_toolbox
    fi
    
    # 检查更新
    check_updates
    
    while true; do
        # 获取服务状态
        local server_status client_status
        server_status=$(check_service_status "gostc-admin")
        client_status=$(check_service_status "gostc")
        
        clear
        echo -e "${PURPLE}"
        echo "══════════════════════════════════════════════════"
        echo -e "        ${WHITE}GOSTC 服务管理工具箱 v${TOOL_VERSION}${PURPLE}"
        echo "══════════════════════════════════════════════════"
        echo -e "${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理 $(display_status "$server_status")"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理 $(display_status "$client_status")"
        echo -e "${CYAN}3. ${WHITE}检查更新"
        echo -e "${CYAN}4. ${WHITE}卸载工具箱"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo ""
        
        read -p "$(echo -e "${BLUE}▷ 请选择操作: ${NC}")" main_choice
        
        case $main_choice in
            1) server_menu ;;
            2) client_menu ;;
            3) check_updates ;;
            4) uninstall_toolbox ;;
            0)
                echo -e "${BLUE}▶ 感谢使用GOSTC工具箱${NC}"
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
