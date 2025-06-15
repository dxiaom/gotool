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

# 工具箱版本
TOOLBOX_VERSION="1.3.0"
TOOLBOX_INSTALL_PATH="/usr/local/bin/gotool"
TOOLBOX_UPDATE_URL="https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh"

# 更新日志
CHANGELOG=(
"版本 1.3.0 (2025-06-15):"
"  - 添加WS/WSS服务器连通性验证"
"  - 优化系统架构检测函数"
"  - 移除所有边框效果"
"  - 添加工具箱更新和卸载功能"
""
"版本 1.2.0 (2025-05-20):"
"  - 添加节点管理功能"
"  - 优化服务端安装流程"
""
"版本 1.1.0 (2025-04-15):"
"  - 添加客户端管理功能"
"  - 修复已知问题"
""
"版本 1.0.0 (2025-03-10):"
"  - 初始版本发布"
)

# 检查是否通过管道安装
if [ -t 0 ]; then
    INTERACTIVE_MODE=true
else
    INTERACTIVE_MODE=false
fi

# 获取系统架构和操作系统
get_system_info() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
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
            return 1
            ;;
    esac
    
    echo "$OS $FILE_SUFFIX"
}

# 验证服务器地址 (使用WS/WSS)
validate_server_address() {
    local address=$1
    local use_tls=$2
    
    # 添加协议前缀
    if [[ "$use_tls" == "true" ]]; then
        if [[ "$address" != wss://* ]]; then
            address="wss://$address"
        fi
    else
        if [[ "$address" != ws://* ]]; then
            address="ws://$address"
        fi
    fi
    
    # 验证服务器是否可达
    echo -e "${BLUE}验证服务器地址: ${WHITE}$address${NC}"
    
    # 使用websocat进行WS/WSS验证
    if command -v websocat &>/dev/null; then
        if timeout 5 websocat -v "$address" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 服务器验证成功${NC}"
            return 0
        else
            echo -e "${RED}✗ 服务器验证失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ 未找到websocat，跳过WS/WSS验证${NC}"
        return 0
    fi
}

# 安装服务端
install_server() {
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
        echo -e "${CYAN}3. ${WHITE}退出${NC}"
        echo ""

        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "$operation_choice" in
            2)
                # 完全重新安装
                echo -e "${YELLOW}开始重新安装服务端...${NC}"
                sudo rm -rf "${TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                echo -e "${BLUE}操作已取消${NC}"
                return
                ;;
            *)
                # 更新操作
                echo -e "${YELLOW}开始更新服务端到最新版本...${NC}"
                UPDATE_MODE=true
                INSTALL_MODE="update"
                ;;
        esac
        echo ""
    else
        INSTALL_MODE="install"
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
            echo -e "${YELLOW}您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac

    echo ""
    echo -e "${BLUE}开始安装服务端 (${VERSION_NAME})${NC}"
    echo -e "${CYAN}==================================================${NC}"

    # 获取系统信息
    system_info=$(get_system_info)
    if [ $? -ne 0 ]; then
        return 1
    fi
    OS=$(echo $system_info | awk '{print $1}')
    FILE_SUFFIX=$(echo $system_info | awk '{print $2}')
    
    echo -e "${BLUE}检测系统: ${WHITE}${OS} ${ARCH}${NC}"

    # 构建下载URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}==================================================${NC}"

    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi

    # 解压文件
    echo ""
    echo -e "${BLUE}正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "${CYAN}==================================================${NC}"

    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        # 保留配置文件
        echo -e "${YELLOW}更新模式: 保留配置文件${NC}"
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
        return 1
    fi

    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}正在初始化服务...${NC}"
    echo -e "${CYAN}==================================================${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install "$@"
    fi

    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务...${NC}"
    echo -e "${CYAN}==================================================${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVICE_NAME"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo ""
    echo -e "${BLUE}服务状态检查${NC}"
    echo -e "${CYAN}==================================================${NC}"

    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}服务已成功启动${NC}"
    else
        echo -e "${YELLOW}服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVICE_NAME}${NC}"
    fi

    # 安装完成提示
    echo ""
    echo -e "${PURPLE}==================================================${NC}"
    echo -e "${PURPLE}                 服务端${INSTALL_MODE:-安装}完成             ${NC}"
    echo -e "${PURPLE}==================================================${NC}"
    echo -e "  操作类型: ${WHITE}$([ "$UPDATE_MODE" = true ] && echo "更新" || echo "${INSTALL_MODE:-安装}")${NC}"
    echo -e "  版本: ${WHITE}${VERSION_NAME}${NC}"
    echo -e "  安装目录: ${WHITE}$TARGET_DIR${NC}"
    echo -e "${PURPLE}==================================================${NC}"
    echo -e "  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${NC}"; else echo -e "${YELLOW}未运行${NC}"; fi)"
    echo -e "  访问地址: ${WHITE}http://localhost:8080${NC}"
    echo -e "  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
    echo -e "${PURPLE}==================================================${NC}"

    # 显示初始凭据（仅在新安装或重新安装时显示）
    if [ ! -f "$CONFIG_FILE" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}==================== 重要提示 ====================${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}==================================================${NC}"
    fi
}

# 服务端管理菜单
server_management_menu() {
    while true; do
        TARGET_DIR="/usr/local/gostc-admin"
        BINARY_NAME="server"
        SERVICE_NAME="gostc-admin"
        
        clear
        echo -e "${BLUE}==================== 服务端管理 ====================${NC}"
        echo -e "${GREEN}当前状态:${NC}"
        
        # 检查服务状态
        if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                echo -e "  服务状态: ${GREEN}运行中${NC}"
            else
                echo -e "  服务状态: ${YELLOW}已停止${NC}"
            fi
            echo -e "  安装路径: ${WHITE}${TARGET_DIR}${NC}"
        else
            echo -e "  服务状态: ${RED}未安装${NC}"
        fi
        
        echo -e "${CYAN}==================================================${NC}"
        echo -e "${WHITE}1. 安装/更新服务端${NC}"
        echo -e "${WHITE}2. 启动服务端${NC}"
        echo -e "${WHITE}3. 停止服务端${NC}"
        echo -e "${WHITE}4. 重启服务端${NC}"
        echo -e "${WHITE}5. 卸载服务端${NC}"
        echo -e "${WHITE}0. 返回主菜单${NC}"
        echo -e "${CYAN}==================================================${NC}"
        
        read -p "请选择操作 [0-5]: " choice
        
        case $choice in
            1) install_server ;;
            2)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在启动服务端...${NC}"
                    sudo systemctl start "$SERVICE_NAME"
                    sleep 2
                    echo -e "${GREEN}服务端已启动${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            3)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在停止服务端...${NC}"
                    sudo systemctl stop "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}服务端已停止${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            4)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在重启服务端...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 2
                    echo -e "${GREEN}服务端已重启${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            5)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在卸载服务端...${NC}"
                    
                    # 停止服务
                    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                        sudo systemctl stop "$SERVICE_NAME"
                    fi
                    
                    # 卸载服务
                    if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                        sudo "${TARGET_DIR}/${BINARY_NAME}" service uninstall
                    fi
                    
                    # 删除文件
                    sudo rm -rf "${TARGET_DIR}"
                    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
                    
                    echo -e "${GREEN}服务端已卸载${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 安装节点/客户端
install_node_client() {
    local component_type=$1
    
    # 配置参数
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    echo ""
    echo -e "${BLUE}开始安装 ${WHITE}${component_type}${BLUE} 组件${NC}"
    echo -e "${CYAN}==================================================${NC}"
    
    # 获取系统信息
    system_info=$(get_system_info)
    if [ $? -ne 0 ]; then
        return 1
    fi
    OS=$(echo $system_info | awk '{print $1}')
    FILE_SUFFIX=$(echo $system_info | awk '{print $2}')
    
    echo -e "${BLUE}检测系统: ${WHITE}${OS} ${ARCH}${NC}"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}下载文件: ${WHITE}${FILE_NAME}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }
    
    # 解压文件
    echo ""
    echo -e "${BLUE}正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    
    sudo rm -f "$TARGET_DIR/$BINARY_NAME"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        return 1
    fi
    
    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 配置提示
    echo ""
    echo -e "${BLUE}${component_type}配置${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    
    if [ "$component_type" == "节点" ]; then
        echo -e "  - 服务器地址 (如: example.com:8080)"
        echo -e "  - 节点密钥 (由服务端提供)"
        echo -e "  - (可选) 网关代理地址${NC}"
    else
        echo -e "  - 服务器地址 (如: example.com:8080)"
        echo -e "  - 客户端密钥 (由服务端提供)${NC}"
    fi
    
    echo -e "${CYAN}==================================================${NC}"
    
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
    
    # 密钥
    local key=""
    while [ -z "$key" ]; do
        if [ "$component_type" == "节点" ]; then
            read -p "$(echo -e "${BLUE}输入节点密钥: ${NC}")" key
        else
            read -p "$(echo -e "${BLUE}输入客户端密钥: ${NC}")" key
        fi
        
        if [ -z "$key" ]; then
            echo -e "${RED}密钥不能为空${NC}"
        fi
    done
    
    # 构建安装命令
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $key"
    
    # 如果是节点，添加-s参数
    if [ "$component_type" == "节点" ]; then
        install_cmd="$install_cmd -s"
        
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
            install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
        fi
    fi
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}正在配置${component_type}${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}${component_type}配置失败${NC}"
        return 1
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}服务启动失败${NC}"
        return 1
    }
    
    echo -e "${GREEN}服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}                 ${component_type}安装成功             ${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "  组件: ${WHITE}${component_type}${NC}"
    echo -e "  安装目录: ${WHITE}$TARGET_DIR${NC}"
    echo -e "  服务器地址: ${WHITE}$server_addr${NC}"
    echo -e "  TLS: ${WHITE}$use_tls${NC}"
    if [ -n "$proxy_base_url" ]; then
        echo -e "  网关地址: ${WHITE}$proxy_base_url${NC}"
    fi
    echo -e "${BLUE}==================================================${NC}"
}

# 节点/客户端管理菜单
node_client_management_menu() {
    while true; do
        TARGET_DIR="/usr/local/bin"
        BINARY_NAME="gostc"
        SERVICE_NAME="gostc"
        
        clear
        echo -e "${BLUE}================ 节点/客户端管理 ================${NC}"
        echo -e "${GREEN}当前状态:${NC}"
        
        # 检查服务状态
        if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                echo -e "  服务状态: ${GREEN}运行中${NC}"
            else
                echo -e "  服务状态: ${YELLOW}已停止${NC}"
            fi
            echo -e "  安装路径: ${WHITE}${TARGET_DIR}${NC}"
        else
            echo -e "  服务状态: ${RED}未安装${NC}"
        fi
        
        echo -e "${CYAN}==================================================${NC}"
        echo -e "${WHITE}1. 安装节点${NC}"
        echo -e "${WHITE}2. 安装客户端${NC}"
        echo -e "${WHITE}3. 启动服务${NC}"
        echo -e "${WHITE}4. 停止服务${NC}"
        echo -e "${WHITE}5. 重启服务${NC}"
        echo -e "${WHITE}6. 卸载服务${NC}"
        echo -e "${WHITE}0. 返回主菜单${NC}"
        echo -e "${CYAN}==================================================${NC}"
        
        read -p "请选择操作 [0-6]: " choice
        
        case $choice in
            1) install_node_client "节点" ;;
            2) install_node_client "客户端" ;;
            3)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在启动服务...${NC}"
                    sudo systemctl start "$SERVICE_NAME"
                    sleep 2
                    echo -e "${GREEN}服务已启动${NC}"
                else
                    echo -e "${RED}错误: 未安装节点/客户端${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            4)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在停止服务...${NC}"
                    sudo systemctl stop "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}服务已停止${NC}"
                else
                    echo -e "${RED}错误: 未安装节点/客户端${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            5)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在重启服务...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 2
                    echo -e "${GREEN}服务已重启${NC}"
                else
                    echo -e "${RED}错误: 未安装节点/客户端${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            6)
                if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${YELLOW}正在卸载服务...${NC}"
                    
                    # 停止服务
                    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                        sudo systemctl stop "$SERVICE_NAME"
                    fi
                    
                    # 卸载服务
                    sudo "${TARGET_DIR}/${BINARY_NAME}" uninstall
                    
                    # 删除文件
                    sudo rm -f "${TARGET_DIR}/${BINARY_NAME}"
                    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
                    
                    echo -e "${GREEN}服务已卸载${NC}"
                else
                    echo -e "${RED}错误: 未安装节点/客户端${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 更新工具箱
update_toolbox() {
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    # 获取远程版本
    remote_version=$(curl -s "$TOOLBOX_UPDATE_URL" | grep -m1 'TOOLBOX_VERSION=' | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        echo -e "${RED}无法获取远程版本信息${NC}"
        return 1
    fi
    
    # 比较版本
    if [ "$remote_version" == "$TOOLBOX_VERSION" ]; then
        echo -e "${GREEN}当前已是最新版本 (v$TOOLBOX_VERSION)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}发现新版本: v${remote_version}${NC}"
    echo -e "${BLUE}当前版本: v${TOOLBOX_VERSION}${NC}"
    echo ""
    
    # 显示更新日志
    echo -e "${PURPLE}================= 更新日志 =================${NC}"
    for line in "${CHANGELOG[@]}"; do
        echo -e "${WHITE}$line${NC}"
    done
    echo -e "${PURPLE}============================================${NC}"
    echo ""
    
    read -p "是否更新到 v${remote_version}? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}更新已取消${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}正在更新工具箱...${NC}"
    
    # 备份当前版本
    cp "$0" "$0.bak"
    
    # 下载新版本
    curl -sL "$TOOLBOX_UPDATE_URL" -o "$0" || {
        echo -e "${RED}更新失败，恢复备份${NC}"
        mv "$0.bak" "$0"
        return 1
    }
    
    # 设置权限
    chmod +x "$0"
    
    echo -e "${GREEN}工具箱已成功更新到 v${remote_version}${NC}"
    echo -e "${YELLOW}请重新运行脚本${NC}"
    
    # 删除备份
    rm -f "$0.bak"
    
    exit 0
}

# 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}正在卸载工具箱...${NC}"
    
    # 删除安装文件
    sudo rm -f "$TOOLBOX_INSTALL_PATH"
    
    echo -e "${GREEN}工具箱已卸载${NC}"
    echo -e "您可以使用以下命令重新安装:"
    echo -e "curl -sL https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh | bash"
    
    exit 0
}

# 主菜单
main_menu() {
    # 非交互模式直接安装工具箱
    if [ "$INTERACTIVE_MODE" = false ]; then
        echo -e "${GREEN}正在安装GOSTC工具箱...${NC}"
        sudo cp "$0" "$TOOLBOX_INSTALL_PATH"
        sudo chmod +x "$TOOLBOX_INSTALL_PATH"
        echo -e "${GREEN}工具箱安装完成!${NC}"
        echo -e "请使用 ${WHITE}gotool${NC} 命令运行工具箱"
        exit 0
    fi

    while true; do
        clear
        echo -e "${PURPLE}==================================================${NC}"
        echo -e "${PURPLE}               GOSTC 服务管理工具箱               ${NC}"
        echo -e "${PURPLE}                     v$TOOLBOX_VERSION                 ${NC}"
        echo -e "${PURPLE}==================================================${NC}"
        echo -e "${WHITE}1. 服务端管理${NC}"
        echo -e "${WHITE}2. 节点/客户端管理${NC}"
        echo -e "${WHITE}3. 更新工具箱${NC}"
        echo -e "${WHITE}4. 卸载工具箱${NC}"
        echo -e "${WHITE}0. 退出${NC}"
        echo -e "${PURPLE}==================================================${NC}"
        
        read -p "请选择操作 [0-4]: " choice
        
        case $choice in
            1) server_management_menu ;;
            2) node_client_management_menu ;;
            3) update_toolbox ;;
            4) uninstall_toolbox ;;
            0)
                echo -e "${BLUE}感谢使用，再见!${NC}"
                exit 0
                ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 检查是否已安装工具箱
if [ ! -f "$TOOLBOX_INSTALL_PATH" ] && [ "$0" != "$TOOLBOX_INSTALL_PATH" ]; then
    echo -e "${GREEN}正在安装GOSTC工具箱...${NC}"
    sudo cp "$0" "$TOOLBOX_INSTALL_PATH"
    sudo chmod +x "$TOOLBOX_INSTALL_PATH"
    echo -e "${GREEN}工具箱安装完成!${NC}"
    echo -e "请使用 ${WHITE}gotool${NC} 命令运行工具箱"
    exit 0
fi

# 启动主菜单
main_menu
