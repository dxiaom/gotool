#!/bin/bash

# 定义颜色代码
'\033[0;35m'
'\033[1;37m'
'\033[0;34m'
'\033[0;32m'
'\033[0;33m'
'\033[0;31m'
'\033[0;36m'
'\033[0m' # 重置颜色

# 脚本信息
"1.0.0"
"gotool"
"https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
"/usr/local/bin/$SCRIPT_NAME"

# 服务端配置
"/usr/local/gostc-admin"
"server"
"gostc-admin"
"${SERVER_TARGET_DIR}/config.yml"

# 节点客户端配置
"/usr/local/bin"
"gostc"
"gostc"

# 首次运行安装
first_run_install() {
"$INSTALL_PATH"then
-e "${YELLOW}▶ 首次运行，安装工具箱到系统...${NC}"
"$0" "$INSTALL_PATH"
"$INSTALL_PATH"
-e "${GREEN}✓ 工具箱安装完成！请使用 ${WHITE}gotool ${GREEN}命令运行工具箱${NC}"
    fi
}

# 检查更新
check_update() {
    echo -e "${BLUE}▶ 检查脚本更新...${NC}"
    remote_content=$(curl -sL "$REMOTE_SCRIPT_URL")
    remote_version=$(echo "$remote_content" | grep -m1 'SCRIPT_VERSION=' | cut -d'"' -f2)
    
    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        echo -e "${YELLOW}发现新版本: $remote_version (当前版本: $SCRIPT_VERSION)${NC}"
        read -p "$(echo -e "${BLUE}是否更新到最新版本? [y/N]: ${NC}")" choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}▶ 更新脚本...${NC}"
            sudo curl -sL "$REMOTE_SCRIPT_URL" -o "$INSTALL_PATH"
            sudo chmod +x "$INSTALL_PATH"
            echo -e "${GREEN}✓ 更新完成! 请重新运行 ${WHITE}gotool${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ 已是最新版本${NC}"
    fi
    echo ""
}

# 打印标题
print_header() {
    local title="$1"
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║               ${WHITE}${title}${PURPLE}               ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示服务状态
show_service_status() {
    local service_name="$1"
    local binary_path="$2"
    
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}✓ 服务运行中${NC}"
    else
        echo -e "${YELLOW}⚠ 服务未运行${NC}"
    fi
    
    if [ -f "$binary_path" ]; then
        echo -e "${GREEN}✓ 二进制文件存在: ${WHITE}$binary_path${NC}"
    else
        echo -e "${RED}✗ 二进制文件不存在${NC}"
    fi
    
    echo ""
}

# 架构检测
detect_architecture() {
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

# 下载并安装文件
download_and_install() {
    local url="$1"
    local target_dir="$2"
    local file_name="$3"
    local binary_name="$4"
    local is_update="$5"
    
    # 下载文件
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${file_name}${NC}"
    curl -# -fL -o "$file_name" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $url${NC}"
        return 1
    }
    
    # 停止服务
    if systemctl is-active --quiet "$SERVER_SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE_NAME"
    fi
    
    # 创建目标目录
    sudo mkdir -p "$target_dir" >/dev/null 2>&1
    
    # 更新模式：保留配置文件
    if [ "$is_update" = true ]; then
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CONFIG_FILE" "${SERVER_CONFIG_FILE}.bak" 2>/dev/null
        sudo find "$target_dir" -maxdepth 1 -type f ! -name '*.yml' -delete
        sudo mv -f "${SERVER_CONFIG_FILE}.bak" "$SERVER_CONFIG_FILE" 2>/dev/null
    fi

    # 解压文件
    if [[ "$file_name" == *.zip ]]; then
        sudo unzip -qo "$file_name" -d "$target_dir"
    elif [[ "$file_name" == *.tar.gz ]]; then
        sudo tar xzf "$file_name" -C "$target_dir"
    else
        echo -e "${RED}错误: 不支持的文件格式: $file_name${NC}"
        return 1
    fi
    
    # 设置权限
    if [ -f "$target_dir/$binary_name" ]; then
        sudo chmod 755 "$target_dir/$binary_name"
        echo -e "${GREEN}✓ 已安装二进制文件: ${target_dir}/${binary_name}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $binary_name${NC}"
        return 1
    fi
    
    # 清理
    rm -f "$file_name"
    return 0
}

# 服务端安装
install_server() {
    print_header "GOSTC 服务端安装"
    
    # 选择版本
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "${CYAN}1. ${WHITE}普通版本${BLUE} (默认)"
    echo -e "${CYAN}2. ${WHITE}商业版本${BLUE} (需要授权)${NC}"
    echo ""

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

    # 检测架构
    file_suffix=$(detect_architecture) || exit 1
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 构建文件名
    FILE_NAME="server_${file_suffix}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    # 检查是否已安装
    is_update=false
    if [ -f "${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}" ]; then
        echo -e "${BLUE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}更新到最新版本${BLUE} (保留配置)"
        echo -e "${CYAN}2. ${WHITE}重新安装最新版本${BLUE} (删除所有文件重新安装)"
        echo -e "${CYAN}3. ${WHITE}退出${NC}"
        echo ""

        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${SERVER_TARGET_DIR}"
                ;;
            3)
                echo -e "${BLUE}操作已取消${NC}"
                return
                ;;
            *)
                is_update=true
                echo -e "${YELLOW}▶ 开始更新服务端到最新版本...${NC}"
                ;;
        esac
        echo ""
    else
        echo -e "${YELLOW}▶ 开始安装服务端...${NC}"
    fi

    # 下载并安装
    if ! download_and_install "$DOWNLOAD_URL" "$SERVER_TARGET_DIR" "$FILE_NAME" "$SERVER_BINARY_NAME" "$is_update"; then
        return
    fi

    # 初始化服务
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" service install
    fi

    # 启动服务
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE_NAME"

    # 检查服务状态
    sleep 2
    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE_NAME")
    
    # 安装完成提示
    echo ""
    print_header "服务端安装完成"
    echo -e "${PURPLE}║  操作类型: ${WHITE}$([ "$is_update" = true ] && echo "更新" || echo "安装")${NC}"
    echo -e "${PURPLE}║  版本: ${WHITE}${VERSION_NAME}${NC}"
    echo -e "${PURPLE}║  安装目录: ${WHITE}${SERVER_TARGET_DIR}${NC}"
    echo -e "${PURPLE}║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${NC}"; else echo -e "${YELLOW}未运行${NC}"; fi)"
    echo -e "${PURPLE}║  访问地址: ${WHITE}http://localhost:8080${NC}"
    echo -e "${PURPLE}║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVER_SERVICE_NAME}${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 显示初始凭据
    if [ ! -f "$SERVER_CONFIG_FILE" ] && [ "$is_update" != "true" ]; then
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
}

# 服务端管理
manage_server() {
    while true; do
        print_header "GOSTC 服务端管理"
        show_service_status "$SERVER_SERVICE_NAME" "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME"
        
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端${NC}"
        echo -e "${CYAN}2. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}3. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}4. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}5. ${WHITE}卸载服务端${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -p "$(echo -e "${BLUE}请输入选项 [0-5]: ${NC}")" choice

        case $choice in
            1) install_server ;;
            2)
                echo -e "${YELLOW}▶ 启动服务...${NC}"
                sudo systemctl start "$SERVER_SERVICE_NAME"
                sleep 1
                ;;
            3)
                echo -e "${YELLOW}▶ 停止服务...${NC}"
                sudo systemctl stop "$SERVER_SERVICE_NAME"
                sleep 1
                ;;
            4)
                echo -e "${YELLOW}▶ 重启服务...${NC}"
                sudo systemctl restart "$SERVER_SERVICE_NAME"
                sleep 1
                ;;
            5)
                echo -e "${YELLOW}▶ 卸载服务端...${NC}"
                if sudo systemctl is-active --quiet "$SERVER_SERVICE_NAME" 2>/dev/null; then
                    sudo systemctl stop "$SERVER_SERVICE_NAME"
                fi
                
                if sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE_NAME}.service"; then
                    echo -e "${YELLOW}▷ 卸载服务...${NC}"
                    sudo "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" service uninstall
                fi
                
                if [ -d "$SERVER_TARGET_DIR" ]; then
                    echo -e "${YELLOW}▷ 删除文件...${NC}"
                    sudo rm -rf "$SERVER_TARGET_DIR"
                fi
                
                echo -e "${GREEN}✓ 服务端已成功卸载${NC}"
                return
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

# 客户端/节点安装
install_client() {
    print_header "GOSTC 客户端/节点安装"
    
    # 选择安装类型
    echo -e "${BLUE}请选择安装类型:${NC}"
    echo -e "${CYAN}1. ${WHITE}节点 (默认)${NC}"
    echo -e "${CYAN}2. ${WHITE}客户端${NC}"
    echo -e "${CYAN}0. ${WHITE}取消${NC}"
    echo ""
    
    read -rp "请输入选项 [0-2]: " client_type
    
    case $client_type in
        1|"") INSTALL_TYPE="node" ;;
        2) INSTALL_TYPE="client" ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选择，使用默认节点安装${NC}"
            INSTALL_TYPE="node"
            ;;
    esac
    
    # 检测架构
    file_suffix=$(detect_architecture) || return
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 构建文件名
    FILE_NAME="gostc_${file_suffix}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="https://alist.sian.one/direct/gostc/${FILE_NAME}"
    
    # 下载并安装
    echo -e "${YELLOW}▶ 开始安装${INSTALL_TYPE}...${NC}"
    
    if ! download_and_install "$DOWNLOAD_URL" "$CLIENT_TARGET_DIR" "$FILE_NAME" "$CLIENT_BINARY_NAME" false; then
        return
    fi
    
    # 配置参数
    local use_tls="false"
    read -p "$(echo -e "${BLUE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    if [[ "$tls_choice" =~ ^[Yy]$ ]]; then
        use_tls="true"
    fi
    
    # 服务器地址
    local server_addr=""
    while [ -z "$server_addr" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (格式: 域名或IP:端口): ${NC}")" server_addr
        if [ -z "$server_addr" ]; then
            echo -e "${RED}✗ 服务器地址不能为空${NC}"
        fi
    done
    
    # 密钥
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入${INSTALL_TYPE}密钥: ${NC}")" key
        if [ -z "$key" ]; then
            echo -e "${RED}✗ 密钥不能为空${NC}"
        fi
    done
    
    # 执行安装命令
    echo -e "${YELLOW}▶ 配置${INSTALL_TYPE}...${NC}"
    local install_cmd="sudo $CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME install --tls=$use_tls -addr $server_addr -key $key"
    
    if [ "$INSTALL_TYPE" = "node" ]; then
        install_cmd="$install_cmd -s"
        echo -e "${BLUE}▷ 节点安装需要额外的网关配置${NC}"
        read -p "$(echo -e "${BLUE}▷ 是否使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
        if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
            local proxy_url=""
            while [ -z "$proxy_url" ]; do
                read -p "$(echo -e "${BLUE}▷ 输入网关地址 (包含http/https前缀): ${NC}")" proxy_url
                if [[ ! "$proxy_url" =~ ^https?:// ]]; then
                    echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
                    proxy_url=""
                fi
            done
            install_cmd="$install_cmd --proxy-base-url $proxy_url"
        fi
    fi
    
    eval "$install_cmd" || {
        echo -e "${RED}✗ ${INSTALL_TYPE}配置失败${NC}"
        return
    }
    
    # 启动服务
    echo -e "${YELLOW}▶ 启动服务...${NC}"
    sudo systemctl start "$CLIENT_SERVICE_NAME"
    
    # 安装完成提示
    echo ""
    print_header "${INSTALL_TYPE}安装完成"
    echo -e "${PURPLE}║  组件类型: ${WHITE}${INSTALL_TYPE}${NC}"
    echo -e "${PURPLE}║  安装目录: ${WHITE}${CLIENT_TARGET_DIR}/${CLIENT_BINARY_NAME}${NC}"
    echo -e "${PURPLE}║  服务器地址: ${WHITE}${server_addr}${NC}"
    echo -e "${PURPLE}║  TLS: ${WHITE}${use_tls}${NC}"
    echo -e "${PURPLE}║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${CLIENT_SERVICE_NAME}${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 客户端/节点管理
manage_client() {
    while true; do
        print_header "GOSTC 客户端/节点管理"
        show_service_status "$CLIENT_SERVICE_NAME" "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME"
        
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新客户端/节点${NC}"
        echo -e "${CYAN}2. ${WHITE}启动服务${NC}"
        echo -e "${CYAN}3. ${WHITE}停止服务${NC}"
        echo -e "${CYAN}4. ${WHITE}重启服务${NC}"
        echo -e "${CYAN}5. ${WHITE}卸载客户端/节点${NC}"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -p "$(echo -e "${BLUE}请输入选项 [0-5]: ${NC}")" choice

        case $choice in
            1) install_client ;;
            2)
                echo -e "${YELLOW}▶ 启动服务...${NC}"
                sudo systemctl start "$CLIENT_SERVICE_NAME"
                sleep 1
                ;;
            3)
                echo -e "${YELLOW}▶ 停止服务...${NC}"
                sudo systemctl stop "$CLIENT_SERVICE_NAME"
                sleep 1
                ;;
            4)
                echo -e "${YELLOW}▶ 重启服务...${NC}"
                sudo systemctl restart "$CLIENT_SERVICE_NAME"
                sleep 1
                ;;
            5)
                echo -e "${YELLOW}▶ 卸载客户端/节点...${NC}"
                if sudo systemctl is-active --quiet "$CLIENT_SERVICE_NAME" 2>/dev/null; then
                    sudo systemctl stop "$CLIENT_SERVICE_NAME"
                fi
                
                if sudo systemctl list-units --full -all | grep -Fq "${CLIENT_SERVICE_NAME}.service"; then
                    echo -e "${YELLOW}▷ 卸载服务...${NC}"
                    sudo "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME" uninstall
                fi
                
                if [ -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME" ]; then
                    echo -e "${YELLOW}▷ 删除文件...${NC}"
                    sudo rm -f "$CLIENT_TARGET_DIR/$CLIENT_BINARY_NAME"
                fi
                
                echo -e "${GREEN}✓ 客户端/节点已成功卸载${NC}"
                return
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

# 主菜单
main_menu() {
    first_run_install
    check_update
    
    while true; do
        print_header "GOSTC 服务管理工具箱"
        echo -e "${PURPLE}║  版本: ${WHITE}${SCRIPT_VERSION}${NC}"
        echo -e "${PURPLE}║  更新命令: ${WHITE}gotool update${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════╝"
        echo ""
        
        echo -e "${BLUE}请选择要管理的服务类型:${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理${NC}"
        echo -e "${CYAN}2. ${WHITE}客户端/节点管理${NC}"
        echo -e "${CYAN}3. ${WHITE}检查更新${NC}"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo ""

        read -p "$(echo -e "${BLUE}请输入选项 [0-3]: ${NC}")" choice

        case $choice in
            1) manage_server ;;
            2) manage_client ;;
            3) check_update ;;
            0)
                echo -e "${GREEN}感谢使用 GOSTC 管理工具箱${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选择! 请重新输入${NC}" ;;
        esac
    done
}

# 处理更新命令
if [ "$1" = "update" ]; then
    echo -e "${YELLOW}▶ 强制更新脚本...${NC}"
    sudo curl -sL "$REMOTE_SCRIPT_URL" -o "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}✓ 更新完成! 请重新运行 ${WHITE}gotool${NC}"
    exit 0
fi

# 启动主菜单
main_menu
