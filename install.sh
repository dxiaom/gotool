#!/bin/bash

# GOSTC 服务管理工具箱
# 版本号: 1.0.0
# 更新日期: 2025-06-15
# 远程更新地址: https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh

# 更新日志:
# 1.0.0 - 初始版本发布
# 1.1.0 - 添加服务管理功能(启动/停止/重启/卸载)
# 1.2.0 - 添加脚本自动更新功能
# 1.3.0 - 优化架构检测和系统信息获取

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 脚本版本
VERSION="1.3.0"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"

# 安装目录
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="gotool"

# 配置参数
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BINARY="server"
SERVER_SERVICE="gostc-admin"

CLIENT_DIR="/usr/local/bin"
CLIENT_BINARY="gostc"
CLIENT_SERVICE="gostc"

# 检查并安装脚本到系统路径
install_script() {
    if [ ! -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
        echo -e "${YELLOW}▶ 正在安装工具箱到系统路径...${NC}"
        sudo cp "$0" "${INSTALL_DIR}/${SCRIPT_NAME}"
        sudo chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
        echo -e "${GREEN}✓ 工具箱安装完成! 您现在可以使用 '${SCRIPT_NAME}' 命令运行本工具${NC}"
        echo ""
    fi
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 检查脚本更新...${NC}"
    remote_version=$(curl -sSfL "$REMOTE_SCRIPT_URL" | grep -m1 "VERSION=\"" | cut -d'"' -f2)
    
    if [[ "$remote_version" != "$VERSION" ]]; then
        echo -e "${YELLOW}发现新版本: $remote_version (当前版本: $VERSION)${NC}"
        read -p "是否更新到最新版本? [y/N] " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}▶ 正在更新脚本...${NC}"
            sudo curl -sSfL "$REMOTE_SCRIPT_URL" -o "${INSTALL_DIR}/${SCRIPT_NAME}"
            sudo chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
            echo -e "${GREEN}✓ 脚本已更新到版本 $remote_version${NC}"
            echo -e "${GREEN}请重新运行 '${SCRIPT_NAME}' 命令${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ 已是最新版本${NC}"
    fi
    echo ""
}

# 打印标题
print_title() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务管理工具箱${PURPLE}             ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}版本: ${WHITE}${VERSION}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
}

# 获取系统信息
get_system_info() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    echo "$OS $ARCH"
}

# 架构检测
detect_arch() {
    ARCH=$1
    
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
    
    echo "$FILE_SUFFIX"
}

# 检查服务状态
check_service_status() {
    service_name=$1
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}运行中${NC}"
        return 0
    else
        echo -e "${YELLOW}未运行${NC}"
        return 1
    fi
}

# 服务端安装
install_server() {
    print_title
    echo -e "${BLUE}▶ 服务端安装${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 检查是否已安装
    if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
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
                sudo rm -rf "${SERVER_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                main_menu
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

    # 处理返回
    if [ "$version_choice" = "0" ]; then
        main_menu
        return
    fi

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
    read -r OS ARCH <<< "$(get_system_info)"
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"

    # 架构检测
    FILE_SUFFIX=$(detect_arch "$ARCH")
    if [ -z "$FILE_SUFFIX" ]; then
        echo -e "${RED}✗ 不支持的架构${NC}"
        press_enter_to_continue
        install_server
        return
    fi

    # 构建下载URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 创建目标目录
    sudo mkdir -p "$SERVER_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        press_enter_to_continue
        install_server
        return
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${SERVER_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "${SERVER_DIR}/config.yml" "${SERVER_DIR}/config.yml.bak" 2>/dev/null
        
        # 删除旧文件但保留配置文件
        sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        
        # 恢复配置文件
        sudo mv -f "${SERVER_DIR}/config.yml.bak" "${SERVER_DIR}/config.yml" 2>/dev/null
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
        press_enter_to_continue
        install_server
        return
    fi

    # 设置权限
    if [ -f "$SERVER_DIR/$SERVER_BINARY" ]; then
        sudo chmod 755 "$SERVER_DIR/$SERVER_BINARY"
        echo -e "${GREEN}✓ 已安装二进制文件: ${SERVER_DIR}/${SERVER_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY${NC}"
        press_enter_to_continue
        install_server
        return
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_DIR/$SERVER_BINARY" service install "$@"
    fi

    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

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
    if [ ! -f "${SERVER_DIR}/config.yml" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi

    press_enter_to_continue
    manage_server
}

# 服务端管理
manage_server() {
    while true; do
        print_title
        echo -e "${BLUE}▶ 服务端管理${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        
        # 检查服务状态
        status=$(check_service_status "$SERVER_SERVICE")
        echo -e "${BLUE}当前状态: $status${NC}"
        echo ""
        
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端${NC}"
        echo -e "${CYAN}2. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}3. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}4. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}5. ${WHITE}卸载服务${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_server ;;
            2)
                echo -e "${YELLOW}▶ 启动服务...${NC}"
                sudo systemctl start "$SERVER_SERVICE"
                sleep 2
                ;;
            3)
                echo -e "${YELLOW}▶ 停止服务...${NC}"
                sudo systemctl stop "$SERVER_SERVICE"
                sleep 2
                ;;
            4)
                echo -e "${YELLOW}▶ 重启服务...${NC}"
                sudo systemctl restart "$SERVER_SERVICE"
                sleep 2
                ;;
            5)
                echo -e "${YELLOW}▶ 卸载服务...${NC}"
                if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
                    sudo systemctl stop "$SERVER_SERVICE"
                fi
                sudo systemctl disable "$SERVER_SERVICE" >/dev/null 2>&1
                sudo rm -f "/etc/systemd/system/${SERVER_SERVICE}.service"
                sudo rm -rf "$SERVER_DIR"
                sudo systemctl daemon-reload
                echo -e "${GREEN}✓ 服务端已卸载${NC}"
                press_enter_to_continue
                return
                ;;
            0)
                main_menu
                return
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
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

# 安装节点或客户端
install_client() {
    local client_type=$1  # "node" 或 "client"
    
    print_title
    echo -e "${BLUE}▶ 安装 ${WHITE}${client_type}${BLUE} 组件${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 获取系统信息
    read -r OS ARCH <<< "$(get_system_info)"
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"
    
    # 架构检测
    FILE_SUFFIX=$(detect_arch "$ARCH")
    if [ -z "$FILE_SUFFIX" ]; then
        echo -e "${RED}✗ 不支持的架构${NC}"
        press_enter_to_continue
        manage_client
        return
    fi
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$CLIENT_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        press_enter_to_continue
        install_client "$client_type"
        return
    }
    
    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${CLIENT_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo rm -f "$CLIENT_DIR/$CLIENT_BINARY"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$CLIENT_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$CLIENT_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        press_enter_to_continue
        install_client "$client_type"
        return
    fi
    
    # 设置权限
    if [ -f "$CLIENT_DIR/$CLIENT_BINARY" ]; then
        sudo chmod 755 "$CLIENT_DIR/$CLIENT_BINARY"
        echo -e "${GREEN}✓ 已安装二进制文件: ${CLIENT_DIR}/${CLIENT_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $CLIENT_BINARY${NC}"
        press_enter_to_continue
        install_client "$client_type"
        return
    fi
    
    # 配置提示
    echo ""
    echo -e "${BLUE}▶ ${WHITE}${client_type}${BLUE} 配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - ${client_type}密钥 (由服务端提供)"
    
    if [ "$client_type" == "节点" ]; then
        echo -e "  - (可选) 网关代理地址${NC}"
    fi
    
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
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入${WHITE}${client_type}${BLUE}密钥: ${NC}")" key
        if [ -z "$key" ]; then
            echo -e "${RED}✗ ${client_type}密钥不能为空${NC}"
        fi
    done
    
    # 网关代理选项 (仅节点)
    local proxy_base_url=""
    if [ "$client_type" == "节点" ]; then
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
    fi
    
    # 构建安装命令
    local install_cmd="sudo $CLIENT_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -key $key"
    
    if [ "$client_type" == "节点" ]; then
        install_cmd="$install_cmd -s"
    fi
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置${WHITE}${client_type}${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ ${client_type}配置失败${NC}"
        press_enter_to_continue
        manage_client
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        press_enter_to_continue
        manage_client
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}${client_type}安装成功${BLUE}                ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}${client_type}${BLUE}                                 ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url${BLUE}               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    press_enter_to_continue
    manage_client
}

# 节点/客户端管理
manage_client() {
    while true; do
        print_title
        echo -e "${BLUE}▶ 节点/客户端管理${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        
        # 检查服务状态
        status=$(check_service_status "$CLIENT_SERVICE")
        echo -e "${BLUE}当前状态: $status${NC}"
        echo ""
        
        echo -e "${CYAN}1. ${WHITE}安装节点${NC}"
        echo -e "${CYAN}2. ${WHITE}安装客户端${NC}"
        echo -e "${CYAN}3. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}4. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}5. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}6. ${WHITE}卸载服务${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_client "节点" ;;
            2) install_client "客户端" ;;
            3)
                echo -e "${YELLOW}▶ 启动服务...${NC}"
                sudo systemctl start "$CLIENT_SERVICE"
                sleep 2
                ;;
            4)
                echo -e "${YELLOW}▶ 停止服务...${NC}"
                sudo systemctl stop "$CLIENT_SERVICE"
                sleep 2
                ;;
            5)
                echo -e "${YELLOW}▶ 重启服务...${NC}"
                sudo systemctl restart "$CLIENT_SERVICE"
                sleep 2
                ;;
            6)
                echo -e "${YELLOW}▶ 卸载服务...${NC}"
                if sudo systemctl is-active --quiet "$CLIENT_SERVICE" 2>/dev/null; then
                    sudo systemctl stop "$CLIENT_SERVICE"
                fi
                sudo systemctl disable "$CLIENT_SERVICE" >/dev/null 2>&1
                sudo rm -f "/etc/systemd/system/${CLIENT_SERVICE}.service"
                sudo rm -f "${CLIENT_DIR}/${CLIENT_BINARY}"
                sudo systemctl daemon-reload
                echo -e "${GREEN}✓ 节点/客户端已卸载${NC}"
                press_enter_to_continue
                return
                ;;
            0)
                main_menu
                return
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 按回车继续
press_enter_to_continue() {
    echo ""
    read -p "按回车键继续..." -n 1 -r
    echo ""
}

# 主菜单
main_menu() {
    while true; do
        print_title
        echo -e "${BLUE}▶ 主菜单${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理${NC}"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理${NC}"
        echo -e "${CYAN}3. ${WHITE}检查更新${NC}"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) manage_server ;;
            2) manage_client ;;
            3) check_update ;;
            0)
                echo -e "${BLUE}▶ 退出工具箱${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 安装脚本并启动
install_script
check_update
main_menu
