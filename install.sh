#!/bin/bash

# GOSTC 服务管理工具箱
# 版本: v2.3
# 更新日志:
# v2.0 - 初始版本，支持服务端和节点的全生命周期管理
# v2.1 - 修复管道安装问题，优化架构检测
# v2.2 - 修复显示对齐问题，优化菜单布局
# v2.3 - 修复更新日志显示问题，优化更新机制

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
TOOL_NAME="gotool"
TOOL_PATH="/usr/local/bin/$TOOL_NAME"
SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"

# 服务端配置
SERVER_TARGET_DIR="/usr/local/gostc-admin"
SERVER_BINARY="server"
SERVER_SERVICE="gostc-admin"
SERVER_CONFIG="$SERVER_TARGET_DIR/config.yml"

# 节点/客户端配置
CLIENT_TARGET_DIR="/usr/local/bin"
CLIENT_BINARY="gostc"
CLIENT_SERVICE="gostc"

# 安装工具箱
install_toolbox() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║            ${WHITE}GOSTC 服务管理工具箱安装${PURPLE}            ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ -f "$TOOL_PATH" ]; then
        echo -e "${GREEN}✓ 工具箱已安装，请使用 ${WHITE}$TOOL_NAME ${GREEN}命令运行${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}▶ 正在从网络下载最新工具箱...${NC}"
    sudo curl -s -o "$TOOL_PATH" "$SCRIPT_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 下载工具箱失败，请检查网络连接！${NC}"
        exit 1
    fi
    sudo chmod +x "$TOOL_PATH"
    
    echo ""
    echo -e "${GREEN}✓ 工具箱安装成功!${NC}"
    echo -e "${BLUE}请使用以下命令运行工具箱: ${WHITE}$TOOL_NAME${NC}"
    echo ""
    exit 0
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务管理工具箱${PURPLE}             ║"
    echo -e "║               ${YELLOW}版本: v2.3${PURPLE}                   ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 架构检测函数
detect_arch() {
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)
    local FILE_SUFFIX=""

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

# 获取服务状态
get_service_status() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}运行中${NC}"
    elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        echo -e "${YELLOW}已停止${NC}"
    else
        echo -e "${RED}未安装${NC}"
    fi
}

# 服务端安装
install_server() {
    show_title
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务端安装向导${PURPLE}              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 检查是否已安装
    local INSTALL_MODE="install"
    local UPDATE_MODE=false
    
    if [ -f "${SERVER_TARGET_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入选项编号 (0-2, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${SERVER_TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            0)
                server_menu
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
    echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
    echo ""

    read -rp "请输入选项编号 (0-2, 默认 1): " version_choice

    # 设置下载URL
    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}▶ 您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        0)
            server_menu
            return
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac

    echo ""
    echo -e "${BLUE}▶ 开始安装 ${PURPLE}服务端 ${BLUE}(${VERSION_NAME})${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 获取架构信息
    local ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 架构检测失败!${NC}"
        exit 1
    fi
    
    local OS=$(echo $ARCH_INFO | cut -d'_' -f1)
    local FILE_SUFFIX=$(echo $ARCH_INFO | cut -d'_' -f2-)
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} $(uname -m)${NC}"
    echo -e "${BLUE}▷ 使用架构: ${WHITE}${FILE_SUFFIX}${NC}"

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
        exit 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${SERVER_TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CONFIG" "${SERVER_CONFIG}.bak" 2>/dev/null
        
        # 删除旧文件但保留配置文件
        sudo find "${SERVER_TARGET_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        
        # 恢复配置文件
        sudo mv -f "${SERVER_CONFIG}.bak" "$SERVER_CONFIG" 2>/dev/null
    else
        # 全新安装模式
        sudo rm -f "$SERVER_TARGET_DIR/$SERVER_BINARY"  # 清理旧版本
    fi

    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$SERVER_TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$SERVER_TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        exit 1
    fi

    # 设置权限
    if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY" ]; then
        sudo chmod 755 "$SERVER_TARGET_DIR/$SERVER_BINARY"
        echo -e "${GREEN}✓ 已安装二进制文件: ${SERVER_TARGET_DIR}/${SERVER_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY${NC}"
        exit 1
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_TARGET_DIR/$SERVER_BINARY" service install
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
    echo -e "║  安装目录: ${WHITE}$SERVER_TARGET_DIR${PURPLE}                     ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)                          ║"
    echo -e "║  访问地址: ${WHITE}http://localhost:8080${PURPLE}             ║"
    echo -e "║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVER_SERVICE}${PURPLE} ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 显示初始凭据
    if [ ! -f "$SERVER_CONFIG" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi

    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 服务端管理菜单
server_menu() {
    while true; do
        show_title
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║                ${WHITE}服务端管理${PURPLE}                  ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  服务状态: $(get_service_status $SERVER_SERVICE)                  ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1. ${WHITE}安装/更新服务端                          ║"
        echo -e "║  ${CYAN}2. ${WHITE}启动服务端                              ║"
        echo -e "║  ${CYAN}3. ${WHITE}停止服务端                              ║"
        echo -e "║  ${CYAN}4. ${WHITE}重启服务端                              ║"
        echo -e "║  ${CYAN}5. ${WHITE}卸载服务端                              ║"
        echo -e "║  ${CYAN}0. ${WHITE}返回主菜单                              ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""

        read -rp "请输入选项编号 (0-5): " choice
        case $choice in
            1) install_server ;;
            2)
                if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY" ]; then
                    sudo systemctl start $SERVER_SERVICE
                    echo -e "${GREEN}✓ 服务已启动${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 1
                fi
                ;;
            3)
                if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY" ]; then
                    sudo systemctl stop $SERVER_SERVICE
                    echo -e "${GREEN}✓ 服务已停止${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 1
                fi
                ;;
            4)
                if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY" ]; then
                    sudo systemctl restart $SERVER_SERVICE
                    echo -e "${GREEN}✓ 服务已重启${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 1
                fi
                ;;
            5)
                if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY" ]; then
                    echo -e "${YELLOW}▶ 正在卸载服务端...${NC}"
                    sudo systemctl stop $SERVER_SERVICE 2>/dev/null
                    sudo systemctl disable $SERVER_SERVICE 2>/dev/null
                    sudo rm -f /etc/systemd/system/$SERVER_SERVICE.service
                    sudo rm -f /usr/lib/systemd/system/$SERVER_SERVICE.service
                    sudo systemctl daemon-reload
                    sudo rm -rf $SERVER_TARGET_DIR
                    echo -e "${GREEN}✓ 服务端已卸载${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 1
                fi
                ;;
            0) main_menu ;;
            *) echo -e "${RED}无效选项!${NC}"; sleep 1 ;;
        esac
    done
}

# 节点/客户端安装
install_client() {
    show_title
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║            ${WHITE}GOSTC 节点/客户端安装向导${PURPLE}          ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 选择安装类型
    echo -e "${BLUE}请选择安装类型:${NC}"
    echo -e "${CYAN}1. ${WHITE}节点 (默认)"
    echo -e "${CYAN}2. ${WHITE}客户端"
    echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
    echo ""
    
    read -rp "请输入选项编号 (0-2, 默认 1): " type_choice
    
    case $type_choice in
        0) client_menu ;;
        2) 
            COMPONENT_TYPE="客户端"
            CONFIG_CMD="client"
            ;;
        *) 
            COMPONENT_TYPE="节点"
            CONFIG_CMD="node"
            ;;
    esac
    
    # 获取架构信息
    local ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 架构检测失败!${NC}"
        exit 1
    fi
    
    local OS=$(echo $ARCH_INFO | cut -d'_' -f1)
    local FILE_SUFFIX=$(echo $ARCH_INFO | cut -d'_' -f2-)
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} $(uname -m)${NC}"
    echo -e "${BLUE}▷ 使用架构: ${WHITE}${FILE_SUFFIX}${NC}"

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
        exit 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$CLIENT_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$CLIENT_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${CLIENT_TARGET_DIR}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    sudo rm -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$CLIENT_TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$CLIENT_TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        exit 1
    fi

    # 设置权限
    if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY" ]; then
        sudo chmod 755 "$CLIENT_TARGET_DIR/$CLIENT_BINARY"
        echo -e "${GREEN}✓ 已安装二进制文件: ${CLIENT_TARGET_DIR}/${CLIENT_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $CLIENT_BINARY${NC}"
        exit 1
    fi

    # 配置提示
    echo ""
    echo -e "${BLUE}▶ ${COMPONENT_TYPE}配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - ${COMPONENT_TYPE}密钥 (由服务端提供)${NC}"
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
        
        # 简单验证地址格式
        if [[ "$input_addr" =~ ^([a-zA-Z0-9.-]+(:[0-9]+)?)$ ]]; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}✗ 无效的地址格式! 请使用 domain.com:port 格式${NC}"
        fi
    done

    # 节点/客户端密钥
    local client_key=""
    while [ -z "$client_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入${COMPONENT_TYPE}密钥: ${NC}")" client_key
        if [ -z "$client_key" ]; then
            echo -e "${RED}✗ ${COMPONENT_TYPE}密钥不能为空${NC}"
        fi
    done

    # 构建安装命令
    local install_cmd="sudo $CLIENT_TARGET_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 如果是节点，添加额外参数
    if [ "$COMPONENT_TYPE" = "节点" ]; then
        install_cmd="$install_cmd -s"
        
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
            install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
        fi
    fi

    # 执行安装命令
    echo ""
    echo -e "${BLUE}▶ 正在配置${COMPONENT_TYPE}${NC}"
    eval "$install_cmd" || {
        echo -e "${RED}✗ ${COMPONENT_TYPE}配置失败${NC}"
        exit 1
    }

    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        exit 1
    }

    echo -e "${GREEN}✓ 服务启动成功${NC}"

    # 安装完成提示
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║               ${WHITE}${COMPONENT_TYPE}安装成功${PURPLE}               ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件类型: ${WHITE}${COMPONENT_TYPE}                          ║"
    echo -e "║  安装目录: ${WHITE}$CLIENT_TARGET_DIR                     ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 节点/客户端管理菜单
client_menu() {
    while true; do
        show_title
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║             ${WHITE}节点/客户端管理${PURPLE}               ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  服务状态: $(get_service_status $CLIENT_SERVICE)                  ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1. ${WHITE}安装/配置节点/客户端                  ║"
        echo -e "║  ${CYAN}2. ${WHITE}启动节点/客户端                      ║"
        echo -e "║  ${CYAN}3. ${WHITE}停止节点/客户端                      ║"
        echo -e "║  ${CYAN}4. ${WHITE}重启节点/客户端                      ║"
        echo -e "║  ${CYAN}5. ${WHITE}卸载节点/客户端                      ║"
        echo -e "║  ${CYAN}0. ${WHITE}返回主菜单                          ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""

        read -rp "请输入选项编号 (0-5): " choice
        case $choice in
            1) install_client ;;
            2)
                if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY" ]; then
                    sudo systemctl start $CLIENT_SERVICE
                    echo -e "${GREEN}✓ 服务已启动${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                    sleep 1
                fi
                ;;
            3)
                if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY" ]; then
                    sudo systemctl stop $CLIENT_SERVICE
                    echo -e "${GREEN}✓ 服务已停止${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                    sleep 1
                fi
                ;;
            4)
                if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY" ]; then
                    sudo systemctl restart $CLIENT_SERVICE
                    echo -e "${GREEN}✓ 服务已重启${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                    sleep 1
                fi
                ;;
            5)
                if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY" ]; then
                    echo -e "${YELLOW}▶ 正在卸载节点/客户端...${NC}"
                    sudo systemctl stop $CLIENT_SERVICE 2>/dev/null
                    sudo systemctl disable $CLIENT_SERVICE 2>/dev/null
                    sudo rm -f /etc/systemd/system/$CLIENT_SERVICE.service
                    sudo rm -f /usr/lib/systemd/system/$CLIENT_SERVICE.service
                    sudo systemctl daemon-reload
                    sudo rm -f $CLIENT_TARGET_DIR/$CLIENT_BINARY
                    echo -e "${GREEN}✓ 节点/客户端已卸载${NC}"
                    sleep 1
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                    sleep 1
                fi
                ;;
            0) main_menu ;;
            *) echo -e "${RED}无效选项!${NC}"; sleep 1 ;;
        esac
    done
}

# 检查更新
check_update() {
    echo -e "${BLUE}▶ 正在检查更新...${NC}"
    remote_content=$(curl -s $SCRIPT_URL)
    
    # 提取远程版本号
    remote_version=$(echo "$remote_content" | grep -m1 "版本: v" | awk -F'v' '{print $2}')
    local_version=$(grep -m1 "版本: v" "$0" | awk -F'v' '{print $2}')
    
    if [ "$remote_version" != "$local_version" ]; then
        echo -e "${GREEN}发现新版本: v$remote_version${NC}"
        echo -e "${YELLOW}更新日志:${NC}"
        
        # 仅显示更新日志部分
        echo "$remote_content" | awk '/^# 更新日志:/{flag=1; next} /^# [^ ]/{flag=0} flag' | sed 's/^# //'
        
        echo ""
        
        read -p "$(echo -e "${BLUE}是否更新到最新版本? (y/n, 默认y): ${NC}")" update_choice
        if [[ ! "$update_choice" =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}▶ 正在更新工具箱...${NC}"
            sudo curl -s -o "$TOOL_PATH" "$SCRIPT_URL"
            sudo chmod +x "$TOOL_PATH"
            echo -e "${GREEN}✓ 工具箱已更新到 v$remote_version${NC}"
            echo -e "${BLUE}请重新运行命令: ${WHITE}$TOOL_NAME${NC}"
            exit 0
        else
            echo -e "${YELLOW}▶ 已取消更新，继续使用当前版本${NC}"
            sleep 1
        fi
    else
        echo -e "${GREEN}✓ 当前已是最新版本 (v$local_version)${NC}"
        sleep 1
    fi
}

# 主菜单
main_menu() {
    # 首次运行时安装工具箱
    if [ ! -f "$TOOL_PATH" ]; then
        install_toolbox
    fi

    # 检查更新
    check_update

    while true; do
        show_title
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║                   ${WHITE}主菜单${PURPLE}                     ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  服务端状态: $(get_service_status $SERVER_SERVICE)                ║"
        echo -e "║  节点状态:   $(get_service_status $CLIENT_SERVICE)                ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1. ${WHITE}服务端管理                           ║"
        echo -e "║  ${CYAN}2. ${WHITE}节点/客户端管理                      ║"
        echo -e "║  ${CYAN}3. ${WHITE}检查更新                             ║"
        echo -e "║  ${CYAN}0. ${WHITE}退出                                ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""

        read -rp "请输入选项编号 (0-3): " choice
        case $choice in
            1) server_menu ;;
            2) client_menu ;;
            3) check_update ;;
            0)
                echo -e "${BLUE}▶ 感谢使用 GOSTC 服务管理工具箱${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选项!${NC}"; sleep 1 ;;
        esac
    done
}

# 脚本入口
main_menu
