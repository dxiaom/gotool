#!/bin/bash

# ==============================================
# GOSTC 服务管理工具箱
# 版本: 1.0.0
# 更新日期: 2025-06-15
# 作者: DeepSeek
# ==============================================

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 脚本信息
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="gotool"
SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
UPDATE_LOG_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/CHANGELOG.md"

# 服务配置
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BINARY="server"
SERVER_SERVICE="gostc-admin"
SERVER_CONFIG="${SERVER_DIR}/config.yml"

CLIENT_DIR="/usr/local/bin"
CLIENT_BINARY="gostc"
CLIENT_SERVICE="gostc"

# ==============================================
# 函数定义
# ==============================================

# 打印标题
print_title() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务管理工具箱${PURPLE}             ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 打印分隔线
print_separator() {
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 检查脚本更新...${NC}"
    remote_version=$(curl -sL ${SCRIPT_URL} | grep "SCRIPT_VERSION=" | head -1 | cut -d'"' -f2)
    
    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "${GREEN}✓ 发现新版本: $remote_version${NC}"
        echo -e "${BLUE}更新日志: ${UPDATE_LOG_URL}${NC}"
        read -p "$(echo -e "${YELLOW}是否更新到最新版本? (y/n, 默认y): ${NC}")" update_choice
        
        if [[ ! "$update_choice" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}▶ 正在更新脚本...${NC}"
            sudo curl -sL ${SCRIPT_URL} -o /tmp/${SCRIPT_NAME} || {
                echo -e "${RED}✗ 更新失败!${NC}"
                return 1
            }
            
            sudo mv /tmp/${SCRIPT_NAME} $(which ${SCRIPT_NAME})
            sudo chmod +x $(which ${SCRIPT_NAME})
            echo -e "${GREEN}✓ 更新成功! 请重新运行命令: ${SCRIPT_NAME}${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ 当前已是最新版本${NC}"
    fi
}

# 安装自身为系统命令
install_self() {
    if [ ! -f "/usr/local/bin/${SCRIPT_NAME}" ]; then
        echo -e "${YELLOW}▶ 安装工具箱为系统命令...${NC}"
        sudo cp "$0" "/usr/local/bin/${SCRIPT_NAME}"
        sudo chmod +x "/usr/local/bin/${SCRIPT_NAME}"
        echo -e "${GREEN}✓ 安装成功! 您现在可以使用命令: ${SCRIPT_NAME}${NC}"
    fi
}

# 获取系统架构
get_architecture() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
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
            return 1
            ;;
    esac

    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    echo "${OS}_${FILE_SUFFIX}"
}

# 显示服务状态
show_service_status() {
    service_name=$1
    
    if systemctl is-enabled "$service_name" &>/dev/null; then
        status=$(systemctl is-active "$service_name")
        if [ "$status" = "active" ]; then
            echo -e "${GREEN}运行中${NC}"
        else
            echo -e "${YELLOW}已停止${NC}"
        fi
    else
        echo -e "${RED}未安装${NC}"
    fi
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

# ==============================================
# 服务端管理函数
# ==============================================

# 安装服务端
server_install() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务端安装向导${PURPLE}              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 检查是否已安装
    if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入选项编号 (0-2, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                # 完全重新安装
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${SERVER_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            0)
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
    echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
    echo ""

    read -rp "请输入选项编号 (0-2, 默认 1): " version_choice
    [ "$version_choice" == "0" ] && return

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
    print_separator

    # 获取系统架构
    ARCH_INFO=$(get_architecture)
    [ $? -ne 0 ] && return
    
    # 构建下载URL
    FILE_NAME="server_${ARCH_INFO}"
    [ "$(echo "$ARCH_INFO" | cut -d'_' -f1)" = "windows" ] && \
        FILE_NAME="${FILE_NAME}.zip" || \
        FILE_NAME="${FILE_NAME}.tar.gz"
    
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    print_separator

    # 创建目标目录
    sudo mkdir -p "$SERVER_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${SERVER_DIR}${NC}"
    print_separator

    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CONFIG" "${SERVER_CONFIG}.bak" 2>/dev/null
        
        # 删除旧文件但保留配置文件
        sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        
        # 恢复配置文件
        sudo mv -f "${SERVER_CONFIG}.bak" "$SERVER_CONFIG" 2>/dev/null
    else
        # 全新安装模式
        sudo rm -f "$SERVER_DIR/$SERVER_BINARY"  # 清理旧版本
    fi

    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$SERVER_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$SERVER_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        return 1
    fi

    # 设置权限
    if [ -f "$SERVER_DIR/$SERVER_BINARY" ]; then
        sudo chmod 755 "$SERVER_DIR/$SERVER_BINARY"
        echo -e "${GREEN}✓ 已安装二进制文件: ${SERVER_DIR}/${SERVER_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY${NC}"
        return 1
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    print_separator

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_DIR/$SERVER_BINARY" service install "$@"
    fi

    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    print_separator

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    print_separator

    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVER_SERVICE}${NC}"
    fi

    # 安装完成提示
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}${INSTALL_MODE:-安装}完成${PURPLE}                   ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  操作类型: ${WHITE}$([ "$UPDATE_MODE" = true ] && echo "更新" || echo "${INSTALL_MODE:-安装}")${PURPLE}                     ║"
    echo -e "║  版本: ${WHITE}${VERSION_NAME}${PURPLE}                             ║"
    echo -e "║  安装目录: ${WHITE}$SERVER_DIR${PURPLE}                     ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)                          ║"
    echo -e "║  访问地址: ${WHITE}http://localhost:8080${PURPLE}             ║"
    echo -e "║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVER_SERVICE}${PURPLE} ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 显示初始凭据（仅在新安装或重新安装时显示）
    if [ ! -f "$SERVER_CONFIG" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
}

# 启动服务端
server_start() {
    if [ ! -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        return 1
    fi
    
    if sudo systemctl is-active --quiet "$SERVER_SERVICE"; then
        echo -e "${YELLOW}服务已在运行中${NC}"
    else
        echo -e "${YELLOW}▶ 启动服务端...${NC}"
        sudo systemctl start "$SERVER_SERVICE"
        sleep 1
        show_service_status "$SERVER_SERVICE"
    fi
}

# 停止服务端
server_stop() {
    if [ ! -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        return 1
    fi
    
    if sudo systemctl is-active --quiet "$SERVER_SERVICE"; then
        echo -e "${YELLOW}▶ 停止服务端...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
        sleep 1
        show_service_status "$SERVER_SERVICE"
    else
        echo -e "${YELLOW}服务已停止${NC}"
    fi
}

# 重启服务端
server_restart() {
    if [ ! -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}▶ 重启服务端...${NC}"
    sudo systemctl restart "$SERVER_SERVICE"
    sleep 1
    show_service_status "$SERVER_SERVICE"
}

# 卸载服务端
server_uninstall() {
    if [ ! -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${RED}错误: 服务端未安装!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}▶ 卸载服务端...${NC}"
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVER_SERVICE"; then
        sudo systemctl stop "$SERVER_SERVICE"
    fi
    
    # 卸载服务
    if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        sudo "${SERVER_DIR}/${SERVER_BINARY}" service uninstall
    fi
    
    # 删除文件
    sudo rm -rf "$SERVER_DIR"
    
    # 禁用服务
    sudo systemctl disable "$SERVER_SERVICE" >/dev/null 2>&1
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ 服务端已成功卸载${NC}"
}

# 服务端管理菜单
server_menu() {
    while true; do
        echo ""
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║              ${WHITE}GOSTC 服务端管理${PURPLE}                 ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  状态: $(show_service_status "$SERVER_SERVICE")${PURPLE}                          ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${WHITE} 安装/更新服务端${PURPLE}                          ║"
        echo -e "║  ${CYAN}2.${WHITE} 启动服务端${PURPLE}                              ║"
        echo -e "║  ${CYAN}3.${WHITE} 停止服务端${PURPLE}                              ║"
        echo -e "║  ${CYAN}4.${WHITE} 重启服务端${PURPLE}                              ║"
        echo -e "║  ${CYAN}5.${WHITE} 卸载服务端${PURPLE}                              ║"
        echo -e "║  ${CYAN}0.${WHITE} 返回主菜单${PURPLE}                              ║"
        echo -e "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-5): " choice
        
        case $choice in
            1) server_install ;;
            2) server_start ;;
            3) server_stop ;;
            4) server_restart ;;
            5) 
                read -p "$(echo -e "${RED}确定要卸载服务端吗? (y/n): ${NC}")" confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && server_uninstall
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

# ==============================================
# 节点/客户端管理函数
# ==============================================

# 安装节点
install_node() {
    # 配置提示
    echo ""
    echo -e "${BLUE}▶ 节点配置${NC}"
    print_separator
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 节点密钥 (由服务端提供)"
    echo -e "  - (可选) 网关代理地址${NC}"
    print_separator
    
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
    local install_cmd="sudo $CLIENT_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -s -key $node_key"
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置节点${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        return 1
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}节点安装成功${BLUE}                  ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}节点${BLUE}                                   ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url${BLUE}               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 安装客户端
install_client() {
    # 配置提示
    echo ""
    echo -e "${BLUE}▶ 客户端配置${NC}"
    print_separator
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 客户端密钥 (由服务端提供)${NC}"
    print_separator
    
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
    local install_cmd="sudo $CLIENT_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        return 1
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}客户端安装成功${BLUE}                ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}客户端${BLUE}                                 ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 安装节点/客户端
client_install() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║             ${WHITE}GOSTC 客户端/节点安装向导${BLUE}            ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 检查是否已安装
    if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        echo -e "${BLUE}检测到已安装客户端/节点，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入选项编号 (0-2, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                # 完全重新安装
                echo -e "${YELLOW}▶ 开始重新安装客户端/节点...${NC}"
                sudo rm -f "${CLIENT_DIR}/${CLIENT_BINARY}"
                ;;
            0)
                return
                ;;
            *)
                # 更新操作
                echo -e "${YELLOW}▶ 开始更新客户端/节点到最新版本...${NC}"
                ;;
        esac
        echo ""
    fi

    echo ""
    echo -e "${BLUE}▶ 请选择安装类型${NC}"
    print_separator
    echo -e "${WHITE}1. 安装节点 (默认)${NC}"
    echo -e "${WHITE}2. 安装客户端${NC}"
    echo -e "${WHITE}0. 返回主菜单${NC}"
    print_separator
    
    local choice
    read -p "$(echo -e "${BLUE}▷ 请输入选择 [0-2] (默认1): ${NC}")" choice
    
    # 设置默认值为1
    [ -z "$choice" ] && choice=1
    
    case $choice in
        1) install_node ;;
        2) install_client ;;
        0) return ;;
        *)
            echo -e "${RED}✗ 无效的选择，默认安装节点${NC}"
            install_node
            ;;
    esac
}

# 启动节点/客户端
client_start() {
    if [ ! -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        return 1
    fi
    
    if sudo systemctl is-active --quiet "$CLIENT_SERVICE"; then
        echo -e "${YELLOW}服务已在运行中${NC}"
    else
        echo -e "${YELLOW}▶ 启动客户端/节点...${NC}"
        sudo systemctl start "$CLIENT_SERVICE"
        sleep 1
        show_service_status "$CLIENT_SERVICE"
    fi
}

# 停止节点/客户端
client_stop() {
    if [ ! -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        return 1
    fi
    
    if sudo systemctl is-active --quiet "$CLIENT_SERVICE"; then
        echo -e "${YELLOW}▶ 停止客户端/节点...${NC}"
        sudo systemctl stop "$CLIENT_SERVICE"
        sleep 1
        show_service_status "$CLIENT_SERVICE"
    else
        echo -e "${YELLOW}服务已停止${NC}"
    fi
}

# 重启节点/客户端
client_restart() {
    if [ ! -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}▶ 重启客户端/节点...${NC}"
    sudo systemctl restart "$CLIENT_SERVICE"
    sleep 1
    show_service_status "$CLIENT_SERVICE"
}

# 卸载节点/客户端
client_uninstall() {
    if [ ! -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        echo -e "${RED}错误: 客户端/节点未安装!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}▶ 卸载客户端/节点...${NC}"
    
    # 停止服务
    if sudo systemctl is-active --quiet "$CLIENT_SERVICE"; then
        sudo systemctl stop "$CLIENT_SERVICE"
    fi
    
    # 卸载服务
    if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
        sudo "${CLIENT_DIR}/${CLIENT_BINARY}" uninstall
    fi
    
    # 删除文件
    sudo rm -f "${CLIENT_DIR}/${CLIENT_BINARY}"
    
    # 禁用服务
    sudo systemctl disable "$CLIENT_SERVICE" >/dev/null 2>&1
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ 客户端/节点已成功卸载${NC}"
}

# 节点/客户端管理菜单
client_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
        echo -e "║             ${WHITE}GOSTC 节点/客户端管理${BLUE}            ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  状态: $(show_service_status "$CLIENT_SERVICE")${BLUE}                          ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${WHITE} 安装/更新节点/客户端${BLUE}                    ║"
        echo -e "║  ${CYAN}2.${WHITE} 启动节点/客户端${BLUE}                        ║"
        echo -e "║  ${CYAN}3.${WHITE} 停止节点/客户端${BLUE}                        ║"
        echo -e "║  ${CYAN}4.${WHITE} 重启节点/客户端${BLUE}                        ║"
        echo -e "║  ${CYAN}5.${WHITE} 卸载节点/客户端${BLUE}                        ║"
        echo -e "║  ${CYAN}0.${WHITE} 返回主菜单${BLUE}                            ║"
        echo -e "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-5): " choice
        
        case $choice in
            1) client_install ;;
            2) client_start ;;
            3) client_stop ;;
            4) client_restart ;;
            5) 
                read -p "$(echo -e "${RED}确定要卸载节点/客户端吗? (y/n): ${NC}")" confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && client_uninstall
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

# ==============================================
# 主菜单
# ==============================================

main_menu() {
    # 首次运行安装自身为系统命令
    install_self
    
    while true; do
        clear
        print_title
        echo -e "${BLUE}脚本版本: ${WHITE}${SCRIPT_VERSION}${NC}"
        echo ""
        
        # 显示服务状态
        echo -e "${BLUE}服务状态:${NC}"
        echo -e "  ▷ 服务端: $(show_service_status "$SERVER_SERVICE")"
        echo -e "  ▷ 节点/客户端: $(show_service_status "$CLIENT_SERVICE")"
        echo ""
        
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║                      ${WHITE}主菜单${PURPLE}                     ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${WHITE} 服务端管理${PURPLE}                            ║"
        echo -e "║  ${CYAN}2.${WHITE} 节点/客户端管理${PURPLE}                       ║"
        echo -e "║  ${CYAN}3.${WHITE} 检查脚本更新${PURPLE}                          ║"
        echo -e "║  ${CYAN}0.${WHITE} 退出${PURPLE}                                 ║"
        echo -e "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-3): " choice
        
        case $choice in
            1) server_menu ;;
            2) client_menu ;;
            3) check_update ;;
            0) 
                echo -e "${GREEN}感谢使用 GOSTC 服务管理工具箱!${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
        
        echo ""
        read -n 1 -s -p "$(echo -e "${BLUE}按任意键继续...${NC}")"
    done
}

# ==============================================
# 脚本入口
# ==============================================

# 确保以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要root权限!${NC}"
    echo -e "请使用以下命令重新运行:"
    echo -e "  sudo $0"
    exit 1
fi

# 启动主菜单
main_menu
