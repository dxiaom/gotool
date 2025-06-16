#!/bin/bash

# 工具箱版本
TOOL_VERSION="1.0.0"

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

# 服务端配置
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BINARY="server"
SERVER_SERVICE="gostc-admin"
SERVER_CONFIG="${SERVER_DIR}/config.yml"

# 节点/客户端配置
CLIENT_DIR="/usr/local/bin"
CLIENT_BINARY="gostc"
CLIENT_SERVICE="gostc"

# 获取服务状态函数
get_service_status() {
    local service_name=$1
    if ! sudo systemctl is-enabled "$service_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}[未安装]${NC}"
    elif sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}[运行中]${NC}"
    else
        local exit_status=$(sudo systemctl show -p ExecMainStatus "$service_name" | cut -d= -f2)
        if [ "$exit_status" -eq 0 ]; then
            echo -e "${YELLOW}[已停止]${NC}"
        else
            echo -e "${RED}[失败]${NC}"
        fi
    fi
}

# 系统架构检测函数
detect_arch() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # Windows系统检测
    [[ "$os" == *"mingw"* || "$os" == *"cygwin"* ]] && os="windows"
    
    case "$arch" in
        "x86_64")
            FILE_SUFFIX="amd64_v1"
            [ "$os" = "linux" ] && {
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
            echo -e "${RED}错误: 不支持的架构: $arch${NC}"
            return 1
            ;;
    esac
    
    echo "${os}_${FILE_SUFFIX}"
}

# 验证服务器地址函数
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
    echo -e "${BLUE}验证服务器地址: ${WHITE}$address${NC}"
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$address")
    
    if [ "$status_code" -eq 200 ]; then
        echo -e "${GREEN}服务器验证成功 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${RED}服务器验证失败 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 安装服务端
install_server() {
    # 选择版本
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "1. 普通版本 (默认)"
    echo -e "2. 商业版本 (需要授权)"
    echo ""

    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice

    # 设置下载URL
    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac

    echo ""
    echo -e "${BLUE}开始安装服务端 (${VERSION_NAME})${NC}"
    echo ""

    # 检测系统架构
    ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # 构建下载URL
    FILE_NAME="server_${ARCH_INFO}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo ""

    # 创建目标目录
    sudo mkdir -p "$SERVER_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        exit 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}正在安装到: ${WHITE}${SERVER_DIR}${NC}"
    echo ""

    # 删除旧文件但保留配置文件
    sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete

    sudo tar xzf "$FILE_NAME" -C "$SERVER_DIR" || {
        echo -e "${RED}错误: 解压文件失败${NC}"
        exit 1
    }

    # 设置权限
    if [ -f "$SERVER_DIR/$SERVER_BINARY" ]; then
        sudo chmod 755 "$SERVER_DIR/$SERVER_BINARY"
        echo -e "${GREEN}已安装二进制文件: ${SERVER_DIR}/${SERVER_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY${NC}"
        exit 1
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}正在初始化服务...${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE}.service"; then
        echo -e "${YELLOW}安装系统服务...${NC}"
        sudo "$SERVER_DIR/$SERVER_BINARY" service install
    fi

    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务...${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}服务状态检查${NC}"
    echo ""

    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}服务已成功启动${NC}"
    else
        echo -e "${YELLOW}服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVER_SERVICE}${NC}"
    fi

    # 安装完成提示
    echo ""
    echo -e "${PURPLE}服务端安装完成${NC}"
    echo -e "操作类型: 安装"
    echo -e "版本: ${VERSION_NAME}"
    echo -e "安装目录: $SERVER_DIR"
    echo -e "服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${NC}"; else echo -e "${YELLOW}未运行${NC}"; fi)"
    echo -e "访问地址: http://localhost:8080"
    echo -e "管理命令: sudo systemctl [start|stop|restart|status] ${SERVER_SERVICE}"

    # 显示初始凭据（仅在新安装时显示）
    if [ ! -f "$SERVER_CONFIG" ]; then
        echo ""
        echo -e "${YELLOW}重要提示: 首次安装，请使用以下默认凭据登录${NC}"
        echo -e "用户名: admin"
        echo -e "密码: admin"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
    fi
}

# 更新服务端
update_server() {
    # 检查是否已安装
    if [ ! -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
        echo -e "${RED}服务端未安装，请先安装${NC}"
        return 1
    fi

    echo -e "${BLUE}开始更新服务端...${NC}"
    echo ""

    # 备份配置文件
    echo -e "${YELLOW}备份配置文件...${NC}"
    sudo cp -f "$SERVER_CONFIG" "${SERVER_CONFIG}.bak" 2>/dev/null

    # 选择版本
    echo -e "${BLUE}请选择更新版本:${NC}"
    echo -e "1. 普通版本 (默认)"
    echo -e "2. 商业版本 (需要授权)"
    echo ""

    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice

    # 设置下载URL
    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac

    # 检测系统架构
    ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # 构建下载URL
    FILE_NAME="server_${ARCH_INFO}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo ""

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 停止服务
    if sudo systemctl is-active --quiet "$SERVER_SERVICE" 2>/dev/null; then
        echo -e "${YELLOW}停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}正在更新文件...${NC}"
    echo ""

    # 删除旧文件但保留配置文件
    sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete

    sudo tar xzf "$FILE_NAME" -C "$SERVER_DIR" || {
        echo -e "${RED}错误: 解压文件失败${NC}"
        return 1
    }

    # 设置权限
    if [ -f "$SERVER_DIR/$SERVER_BINARY" ]; then
        sudo chmod 755 "$SERVER_DIR/$SERVER_BINARY"
        echo -e "${GREEN}已更新二进制文件: ${SERVER_DIR}/${SERVER_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY${NC}"
        return 1
    fi

    # 恢复配置文件
    echo -e "${YELLOW}恢复配置文件...${NC}"
    sudo mv -f "${SERVER_CONFIG}.bak" "$SERVER_CONFIG" 2>/dev/null

    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务...${NC}"

    sudo systemctl daemon-reload
    sudo systemctl restart "$SERVER_SERVICE"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}服务状态检查${NC}"
    echo ""

    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}服务已成功启动${NC}"
    else
        echo -e "${YELLOW}服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVER_SERVICE}${NC}"
    fi

    # 更新完成提示
    echo ""
    echo -e "${PURPLE}服务端更新完成${NC}"
    echo -e "操作类型: 更新"
    echo -e "版本: ${VERSION_NAME}"
    echo -e "服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${NC}"; else echo -e "${YELLOW}未运行${NC}"; fi)"
}

# 服务端管理菜单
server_management_menu() {
    while true; do
        SERVER_STATUS=$(get_service_status "$SERVER_SERVICE")
        
        echo ""
        echo -e "${PURPLE}GOSTC 服务端管理 ${SERVER_STATUS}${NC}"
        echo -e "${CYAN}==============================${NC}"
        echo -e "1. 安装服务端"
        echo -e "2. 更新服务端"
        echo -e "3. 启动服务"
        echo -e "4. 停止服务"
        echo -e "5. 重启服务"
        echo -e "6. 卸载服务"
        echo -e "0. 返回主菜单"
        echo -e "${CYAN}==============================${NC}"
        
        read -p "请选择操作 (0-6): " choice
        
        case $choice in
            1) install_server ;;
            2) update_server ;;
            3)
                if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
                    sudo systemctl start "$SERVER_SERVICE"
                    echo -e "${GREEN}服务已启动${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            4)
                if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
                    sudo systemctl stop "$SERVER_SERVICE"
                    echo -e "${GREEN}服务已停止${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            5)
                if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
                    sudo systemctl restart "$SERVER_SERVICE"
                    echo -e "${GREEN}服务已重启${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            6)
                if [ -f "${SERVER_DIR}/${SERVER_BINARY}" ]; then
                    echo -e "${YELLOW}正在卸载服务端...${NC}"
                    sudo systemctl stop "$SERVER_SERVICE" >/dev/null 2>&1
                    sudo systemctl disable "$SERVER_SERVICE" >/dev/null 2>&1
                    sudo rm -f "/etc/systemd/system/${SERVER_SERVICE}.service"
                    sudo rm -rf "$SERVER_DIR"
                    sudo systemctl daemon-reload
                    echo -e "${GREEN}服务端已卸载${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 安装节点
install_node() {
    # 检测系统架构
    ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${ARCH_INFO}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}开始安装节点...${NC}"
    echo ""

    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo ""

    # 创建目标目录
    sudo mkdir -p "$CLIENT_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 解压文件
    echo ""
    echo -e "${BLUE}正在安装到: ${WHITE}${CLIENT_DIR}${NC}"
    echo ""

    sudo rm -f "$CLIENT_DIR/$CLIENT_BINARY"  # 清理旧版本
    sudo tar xzf "$FILE_NAME" -C "$CLIENT_DIR" || {
        echo -e "${RED}错误: 解压文件失败${NC}"
        return 1
    }

    # 设置权限
    if [ -f "$CLIENT_DIR/$CLIENT_BINARY" ]; then
        sudo chmod 755 "$CLIENT_DIR/$CLIENT_BINARY"
        echo -e "${GREEN}已安装二进制文件: ${CLIENT_DIR}/${CLIENT_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $CLIENT_BINARY${NC}"
        return 1
    fi

    # 清理
    rm -f "$FILE_NAME"

    # 配置提示
    echo ""
    echo -e "${BLUE}节点配置${NC}"
    echo ""
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 节点密钥 (由服务端提供)"
    echo -e "  - (可选) 网关代理地址${NC}"
    echo ""

    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    if [[ "$tls_choice" =~ ^[Yy]$ ]]; then
        use_tls="true"
    fi

    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}请重新输入有效的服务器地址${NC}"
        fi
    done

    # 节点密钥
    local node_key=""
    while [ -z "$node_key" ]; do
        read -p "$(echo -e "${BLUE}输入节点密钥: ${NC}")" node_key
        if [ -z "$node_key" ]; then
            echo -e "${RED}节点密钥不能为空${NC}"
        fi
    done

    # 网关代理选项
    local proxy_base_url=""
    read -p "$(echo -e "${BLUE}是否使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "$(echo -e "${BLUE}输入网关地址 (包含http/https前缀): ${NC}")" proxy_url
            if [[ "$proxy_url" =~ ^https?:// ]]; then
                proxy_base_url="$proxy_url"
                break
            else
                echo -e "${RED}网关地址必须以http://或https://开头${NC}"
            fi
        done
    fi

    # 构建安装命令
    local install_cmd="sudo $CLIENT_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -s -key $node_key"
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi

    # 执行安装命令
    echo -e "${BLUE}正在配置节点...${NC}"
    eval "$install_cmd" || {
        echo -e "${RED}节点配置失败${NC}"
        return 1
    }

    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}服务启动失败${NC}"
        return 1
    }

    echo -e "${GREEN}服务启动成功${NC}"

    # 安装完成提示
    echo ""
    echo -e "${BLUE}节点安装成功${NC}"
    echo -e "组件: 节点"
    echo -e "安装目录: $CLIENT_DIR"
    echo -e "服务器地址: $server_addr"
    echo -e "TLS: $use_tls"
    if [ -n "$proxy_base_url" ]; then
        echo -e "网关地址: $proxy_base_url"
    fi
}

# 安装客户端
install_client() {
    # 检测系统架构
    ARCH_INFO=$(detect_arch)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${ARCH_INFO}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}开始安装客户端...${NC}"
    echo ""

    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo ""

    # 创建目标目录
    sudo mkdir -p "$CLIENT_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 解压文件
    echo ""
    echo -e "${BLUE}正在安装到: ${WHITE}${CLIENT_DIR}${NC}"
    echo ""

    sudo rm -f "$CLIENT_DIR/$CLIENT_BINARY"  # 清理旧版本
    sudo tar xzf "$FILE_NAME" -C "$CLIENT_DIR" || {
        echo -e "${RED}错误: 解压文件失败${NC}"
        return 1
    }

    # 设置权限
    if [ -f "$CLIENT_DIR/$CLIENT_BINARY" ]; then
        sudo chmod 755 "$CLIENT_DIR/$CLIENT_BINARY"
        echo -e "${GREEN}已安装二进制文件: ${CLIENT_DIR}/${CLIENT_BINARY}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $CLIENT_BINARY${NC}"
        return 1
    fi

    # 清理
    rm -f "$FILE_NAME"

    # 配置提示
    echo ""
    echo -e "${BLUE}客户端配置${NC}"
    echo ""
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 客户端密钥 (由服务端提供)${NC}"
    echo ""

    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    if [[ "$tls_choice" =~ ^[Yy]$ ]]; then
        use_tls="true"
    fi

    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        else
            echo -e "${RED}请重新输入有效的服务器地址${NC}"
        fi
    done

    # 客户端密钥
    local client_key=""
    while [ -z "$client_key" ]; do
        read -p "$(echo -e "${BLUE}输入客户端密钥: ${NC}")" client_key
        if [ -z "$client_key" ]; then
            echo -e "${RED}客户端密钥不能为空${NC}"
        fi
    done

    # 构建安装命令
    local install_cmd="sudo $CLIENT_DIR/$CLIENT_BINARY install --tls=$use_tls -addr $server_addr -key $client_key"

    # 执行安装命令
    echo -e "${BLUE}正在配置客户端...${NC}"
    eval "$install_cmd" || {
        echo -e "${RED}客户端配置失败${NC}"
        return 1
    }

    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务${NC}"
    sudo systemctl start "$CLIENT_SERVICE" || {
        echo -e "${RED}服务启动失败${NC}"
        return 1
    }

    echo -e "${GREEN}服务启动成功${NC}"

    # 安装完成提示
    echo ""
    echo -e "${BLUE}客户端安装成功${NC}"
    echo -e "组件: 客户端"
    echo -e "安装目录: $CLIENT_DIR"
    echo -e "服务器地址: $server_addr"
    echo -e "TLS: $use_tls"
}

# 节点/客户端管理菜单
client_management_menu() {
    while true; do
        CLIENT_STATUS=$(get_service_status "$CLIENT_SERVICE")
        
        echo ""
        echo -e "${PURPLE}GOSTC 节点/客户端管理 ${CLIENT_STATUS}${NC}"
        echo -e "${CYAN}==============================${NC}"
        echo -e "1. 安装节点"
        echo -e "2. 安装客户端"
        echo -e "3. 启动服务"
        echo -e "4. 停止服务"
        echo -e "5. 重启服务"
        echo -e "6. 卸载服务"
        echo -e "0. 返回主菜单"
        echo -e "${CYAN}==============================${NC}"
        
        read -p "请选择操作 (0-6): " choice
        
        case $choice in
            1) install_node ;;
            2) install_client ;;
            3)
                if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
                    sudo systemctl start "$CLIENT_SERVICE"
                    echo -e "${GREEN}服务已启动${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            4)
                if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
                    sudo systemctl stop "$CLIENT_SERVICE"
                    echo -e "${GREEN}服务已停止${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            5)
                if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
                    sudo systemctl restart "$CLIENT_SERVICE"
                    echo -e "${GREEN}服务已重启${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            6)
                if [ -f "${CLIENT_DIR}/${CLIENT_BINARY}" ]; then
                    echo -e "${YELLOW}正在卸载节点/客户端...${NC}"
                    sudo systemctl stop "$CLIENT_SERVICE" >/dev/null 2>&1
                    sudo systemctl disable "$CLIENT_SERVICE" >/dev/null 2>&1
                    sudo rm -f "/etc/systemd/system/${CLIENT_SERVICE}.service"
                    sudo rm -f "$CLIENT_DIR/$CLIENT_BINARY"
                    sudo systemctl daemon-reload
                    echo -e "${GREEN}节点/客户端已卸载${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 工具箱自身管理
toolbox_management() {
    while true; do
        echo ""
        echo -e "${PURPLE}工具箱管理${NC}"
        echo -e "${CYAN}==============================${NC}"
        echo -e "1. 更新工具箱"
        echo -e "2. 卸载工具箱"
        echo -e "0. 返回主菜单"
        echo -e "${CYAN}==============================${NC}"
        
        read -p "请选择操作 (0-2): " choice
        
        case $choice in
            1)
                echo -e "${BLUE}正在检查更新...${NC}"
                LATEST_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
                
                # 下载最新版本
                if curl -s -fL -o "/tmp/gotool_latest" "$LATEST_URL"; then
                    # 比较版本
                    CURRENT_VERSION=$TOOL_VERSION
                    LATEST_VERSION=$(grep -m1 'TOOL_VERSION=' "/tmp/gotool_latest" | cut -d'"' -f2)
                    
                    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
                        echo -e "${GREEN}当前已是最新版本 (v$CURRENT_VERSION)${NC}"
                    else
                        echo -e "${YELLOW}发现新版本: v$LATEST_VERSION${NC}"
                        echo -e "当前版本: v$CURRENT_VERSION"
                        echo ""
                        
                        # 显示更新日志
                        echo -e "${BLUE}更新日志:${NC}"
                        awk '/^# 更新日志开始/,/^# 更新日志结束/' "/tmp/gotool_latest" | sed '1d;$d'
                        echo ""
                        
                        read -p "是否更新到最新版本? (y/n): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            sudo cp "/tmp/gotool_latest" "$TOOL_PATH"
                            sudo chmod +x "$TOOL_PATH"
                            echo -e "${GREEN}工具箱已更新到 v$LATEST_VERSION${NC}"
                            echo -e "${YELLOW}请重新运行 gotool${NC}"
                            exit 0
                        else
                            echo -e "${YELLOW}已取消更新${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}检查更新失败${NC}"
                fi
                rm -f "/tmp/gotool_latest"
                ;;
            2)
                echo -e "${YELLOW}正在卸载工具箱...${NC}"
                sudo rm -f "$TOOL_PATH"
                echo -e "${GREEN}工具箱已卸载${NC}"
                echo -e "${YELLOW}感谢使用，再见！${NC}"
                exit 0
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 主菜单
main_menu() {
    # 首次运行提示
    if [ ! -f "$TOOL_PATH" ]; then
        echo -e "${GREEN}工具箱安装完成${NC}"
        echo -e "请使用 ${PURPLE}gotool${NC} 命令运行工具箱"
        echo ""
    fi
    
    while true; do
        SERVER_STATUS=$(get_service_status "$SERVER_SERVICE")
        CLIENT_STATUS=$(get_service_status "$CLIENT_SERVICE")
        
        echo ""
        echo -e "${PURPLE}GOSTC 服务管理工具箱 v${TOOL_VERSION}${NC}"
        echo -e "${CYAN}=================================${NC}"
        echo -e "1. 服务端管理 ${SERVER_STATUS}"
        echo -e "2. 节点/客户端管理 ${CLIENT_STATUS}"
        echo -e "3. 工具箱管理"
        echo -e "0. 退出"
        echo -e "${CYAN}=================================${NC}"
        
        read -p "请选择操作 (0-3): " choice
        
        case $choice in
            1) server_management_menu ;;
            2) client_management_menu ;;
            3) toolbox_management ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" ;;
        esac
    done
}

# 安装模式 (通过管道安装)
if [ ! -f "$TOOL_PATH" ]; then
    echo -e "${BLUE}正在安装 GOSTC 工具箱...${NC}"
    sudo curl -s -fL -o "$TOOL_PATH" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
    
    if [ $? -eq 0 ]; then
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}工具箱已安装到 ${TOOL_PATH}${NC}"
        echo -e "请使用 ${PURPLE}gotool${NC} 命令运行工具箱"
    else
        echo -e "${RED}工具箱安装失败${NC}"
        exit 1
    fi
else
    # 正常模式 (显示菜单)
    main_menu
fi

# 更新日志开始
# 版本 1.0.0 (2023-11-15)
# - 初始版本发布
# - 支持服务端安装、更新、启动、停止、重启和卸载
# - 支持节点/客户端安装、启动、停止、重启和卸载
# - 支持工具箱自身更新和卸载
# 更新日志结束
