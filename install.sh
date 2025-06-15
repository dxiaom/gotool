#!/bin/bash

# GOSTC 工具箱脚本
# 版本: 1.2.1

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
TOOLBOX_PATH="/usr/local/bin/gotool"
# 工具箱版本
TOOLBOX_VERSION="1.2.1"
# 更新日志
CHANGELOG="
版本 1.2.1 更新日志:
- 修复管道安装时直接安装服务端的问题
- 优化WS/WSS服务器验证功能
- 改进服务管理界面
- 添加服务状态实时显示
"

# 安装模式判断
if [ ! -t 0 ]; then
    # 非交互模式（管道安装）- 只安装工具箱
    echo -e "${GREEN}▶ 正在安装GOSTC工具箱...${NC}"
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    TMP_SCRIPT="$TMP_DIR/gotool_install.sh"
    
    # 下载最新脚本
    echo -e "${BLUE}▷ 下载工具箱脚本...${NC}"
    curl -sSL -o "$TMP_SCRIPT" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 下载工具箱脚本失败${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 安装工具箱
    sudo install -m 755 "$TMP_SCRIPT" "$TOOLBOX_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 工具箱安装成功!${NC}"
        echo -e "${YELLOW}请使用 'gotool' 命令运行工具箱${NC}"
    else
        echo -e "${RED}✗ 工具箱安装失败${NC}"
    fi
    
    # 清理
    rm -rf "$TMP_DIR"
    exit 0
fi

# 函数: 获取系统信息
get_system_info() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
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
        "riscv64") FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x")   FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}"
            return 1
            ;;
    esac
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    echo "$OS $ARCH $FILE_SUFFIX"
}

# 函数: 验证服务器地址 (WS/WSS)
validate_server_ws() {
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
    
    echo -e "${BLUE}▷ 验证服务器连通性: ${WHITE}$address${NC}"
    
    # 使用curl测试WebSocket连接
    local response
    response=$(curl -sS -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" "$address" 2>&1)
    
    if [[ "$response" == *"101 Switching Protocols"* ]]; then
        echo -e "${GREEN}✓ 服务器验证成功 (WebSocket连接正常)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败${NC}"
        echo -e "${YELLOW}响应信息:${NC}"
        echo "$response"
        return 1
    fi
}

# 函数: 安装工具箱
install_toolbox() {
    echo -e "${GREEN}▶ 正在安装GOSTC工具箱...${NC}"
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    TMP_SCRIPT="$TMP_DIR/gotool_install.sh"
    
    # 下载最新脚本
    echo -e "${BLUE}▷ 下载工具箱脚本...${NC}"
    curl -sSL -o "$TMP_SCRIPT" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 下载工具箱脚本失败${NC}"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    # 安装工具箱
    sudo install -m 755 "$TMP_SCRIPT" "$TOOLBOX_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 工具箱安装成功!${NC}"
        echo -e "${YELLOW}请使用 'gotool' 命令运行工具箱${NC}"
    else
        echo -e "${RED}✗ 工具箱安装失败${NC}"
    fi
    
    # 清理
    rm -rf "$TMP_DIR"
}

# 函数: 更新工具箱
update_toolbox() {
    echo -e "${YELLOW}▶ 正在检查工具箱更新...${NC}"
    
    # 获取最新版本
    LATEST_VERSION=$(curl -sSL "https://raw.githubusercontent.com/dxiaom/gotool/main/version.txt")
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}✗ 无法获取最新版本信息${NC}"
        return 1
    fi
    
    if [ "$LATEST_VERSION" = "$TOOLBOX_VERSION" ]; then
        echo -e "${GREEN}✓ 您的工具箱已是最新版本 ($TOOLBOX_VERSION)${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}发现新版本: $LATEST_VERSION${NC}"
    echo -e "${CYAN}更新日志:${NC}$CHANGELOG"
    echo ""
    
    read -p "$(echo -e "${BLUE}是否要更新到最新版本? (y/n) [n]: ${NC}")" choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
        
        # 创建临时目录
        TMP_DIR=$(mktemp -d)
        TMP_SCRIPT="$TMP_DIR/gotool_install.sh"
        
        # 下载最新脚本
        curl -sSL -o "$TMP_SCRIPT" "https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ 下载最新工具箱失败${NC}"
            rm -rf "$TMP_DIR"
            return 1
        fi
        
        # 安装更新
        sudo install -m 755 "$TMP_SCRIPT" "$TOOLBOX_PATH"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 工具箱已成功更新到 $LATEST_VERSION${NC}"
            echo -e "${YELLOW}请重新运行工具箱查看更新${NC}"
            rm -rf "$TMP_DIR"
            exit 0
        else
            echo -e "${RED}✗ 更新失败${NC}"
        fi
        
        rm -rf "$TMP_DIR"
    else
        echo -e "${BLUE}▶ 已取消更新${NC}"
    fi
}

# 函数: 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 正在卸载GOSTC工具箱...${NC}"
    
    if [ -f "$TOOLBOX_PATH" ]; then
        sudo rm -f "$TOOLBOX_PATH"
        echo -e "${GREEN}✓ 工具箱已成功卸载${NC}"
    else
        echo -e "${RED}✗ 工具箱未安装${NC}"
    fi
    
    exit 0
}

# 函数: 安装服务端
install_server() {
    # 配置参数
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    local CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    echo -e "${BLUE}▶ 开始安装GOSTC服务端${NC}"
    
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

    # 获取系统信息
    local system_info
    system_info=$(get_system_info)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local OS=$(echo $system_info | awk '{print $1}')
    local ARCH=$(echo $system_info | awk '{print $2}')
    local FILE_SUFFIX=$(echo $system_info | awk '{print $3}')
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"

    # 构建下载URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"

    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi

    # 解压文件
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"

    # 删除旧文件但保留配置文件
    sudo find "${TARGET_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete

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
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi

    # 初始化服务
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install "$@"
    fi

    # 启动服务
    echo -e "${BLUE}▶ 正在启动服务...${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVICE_NAME"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    echo -e "${BLUE}▶ 服务状态检查${NC}"

    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVICE_NAME}${NC}"
    fi

    # 安装完成提示
    echo -e "${GREEN}✓ 服务端安装完成!${NC}"
    echo -e "${BLUE}版本: ${WHITE}${VERSION_NAME}${NC}"
    echo -e "${BLUE}安装目录: ${WHITE}$TARGET_DIR${NC}"
    echo -e "${BLUE}管理命令:"
    echo -e "  sudo systemctl start ${SERVICE_NAME}"
    echo -e "  sudo systemctl stop ${SERVICE_NAME}"
    echo -e "  sudo systemctl restart ${SERVICE_NAME}"
    echo -e "  sudo systemctl status ${SERVICE_NAME}${NC}"
    
    # 显示初始凭据（仅在新安装时显示）
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
}

# 函数: 服务端管理
manage_server() {
    local SERVICE_NAME="gostc-admin"
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_PATH="${TARGET_DIR}/server"
    
    while true; do
        # 显示服务状态
        echo -e "${BLUE}════════════════ 服务端管理 ════════════════${NC}"
        
        if [ -f "$BINARY_PATH" ]; then
            SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "未运行")
            echo -e "${BLUE}当前服务状态: ${WHITE}$SERVICE_STATUS${NC}"
        else
            echo -e "${RED}服务端未安装${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端"
        echo -e "${CYAN}2. ${WHITE}启动服务"
        echo -e "${CYAN}3. ${WHITE}停止服务"
        echo -e "${CYAN}4. ${WHITE}重启服务"
        echo -e "${CYAN}5. ${WHITE}卸载服务端"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入选项 (0-5): " choice
        
        case $choice in
            1)
                install_server
                ;;
            2)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                    sudo systemctl start "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已启动${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            3)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                    sudo systemctl stop "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已停止${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            4)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已重启${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            5)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在卸载服务端...${NC}"
                    
                    # 停止服务
                    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
                    
                    # 卸载服务
                    sudo "$BINARY_PATH" service uninstall
                    
                    # 删除文件
                    sudo rm -rf "$TARGET_DIR"
                    
                    # 禁用服务
                    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
                    
                    echo -e "${GREEN}✓ 服务端已卸载${NC}"
                else
                    echo -e "${RED}服务端未安装${NC}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        
        echo ""
        read -p "$(echo -e "${BLUE}按Enter键继续...${NC}")" 
    done
}

# 函数: 安装节点客户端
install_node_client() {
    local TYPE=$1 # node 或 client
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    local BINARY_PATH="${TARGET_DIR}/${BINARY_NAME}"
    
    echo -e "${BLUE}▶ 开始安装GOSTC $TYPE${NC}"
    
    # 获取系统信息
    local system_info
    system_info=$(get_system_info)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local OS=$(echo $system_info | awk '{print $1}')
    local ARCH=$(echo $system_info | awk '{print $2}')
    local FILE_SUFFIX=$(echo $system_info | awk '{print $3}')
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"

    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"

    # 创建目标目录
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
    }

    # 解压文件
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"

    sudo rm -f "$BINARY_PATH"  # 清理旧版本
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    elif [[ "$FILE_NAME" == *.tar.gz ]]; then
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    else
        echo -e "${RED}错误: 不支持的文件格式: $FILE_NAME${NC}"
        return 1
    fi

    # 设置权限
    if [ -f "$BINARY_PATH" ]; then
        sudo chmod 755 "$BINARY_PATH"
        echo -e "${GREEN}✓ 已安装二进制文件: ${BINARY_PATH}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi

    # 清理
    rm -f "$FILE_NAME"
    
    # 配置提示
    echo -e "${BLUE}▶ ${TYPE}配置${NC}"
    
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
    
    # 密钥
    local key=""
    while [ -z "$key" ]; do
        if [ "$TYPE" == "节点" ]; then
            read -p "$(echo -e "${BLUE}▷ 输入节点密钥: ${NC}")" key
        else
            read -p "$(echo -e "${BLUE}▷ 输入客户端密钥: ${NC}")" key
        fi
        
        if [ -z "$key" ]; then
            echo -e "${RED}✗ 密钥不能为空${NC}"
        fi
    done
    
    # 构建安装命令
    local install_cmd="sudo $BINARY_PATH install --tls=$use_tls -addr $server_addr"
    
    if [ "$TYPE" == "节点" ]; then
        install_cmd="$install_cmd -s -key $key"
    else
        install_cmd="$install_cmd -key $key"
    fi
    
    # 网关代理选项
    if [ "$TYPE" == "节点" ]; then
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
    echo -e "${BLUE}▶ 正在配置$TYPE${NC}"
    eval "$install_cmd" || {
        echo -e "${RED}✗ ${TYPE}配置失败${NC}"
        return 1
    }
    
    # 启动服务
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo -e "${GREEN}✓ $TYPE 安装完成!${NC}"
    echo -e "${BLUE}服务器地址: ${WHITE}$server_addr${NC}"
    echo -e "${BLUE}TLS: ${WHITE}$use_tls${NC}"
    
    if [ -n "$proxy_base_url" ]; then
        echo -e "${BLUE}网关地址: ${WHITE}$proxy_base_url${NC}"
    fi
    
    echo -e "${BLUE}管理命令:"
    echo -e "  sudo systemctl start ${SERVICE_NAME}"
    echo -e "  sudo systemctl stop ${SERVICE_NAME}"
    echo -e "  sudo systemctl restart ${SERVICE_NAME}"
    echo -e "  sudo systemctl status ${SERVICE_NAME}${NC}"
}

# 函数: 节点/客户端管理
manage_node_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    local BINARY_PATH="${TARGET_DIR}/${BINARY_NAME}"
    
    while true; do
        # 显示服务状态
        echo -e "${BLUE}════════════ 节点/客户端管理 ═════════════${NC}"
        
        if [ -f "$BINARY_PATH" ]; then
            SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "未运行")
            echo -e "${BLUE}当前服务状态: ${WHITE}$SERVICE_STATUS${NC}"
        else
            echo -e "${RED}节点/客户端未安装${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装节点"
        echo -e "${CYAN}2. ${WHITE}安装客户端"
        echo -e "${CYAN}3. ${WHITE}启动服务"
        echo -e "${CYAN}4. ${WHITE}停止服务"
        echo -e "${CYAN}5. ${WHITE}重启服务"
        echo -e "${CYAN}6. ${WHITE}卸载节点/客户端"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入选项 (0-6): " choice
        
        case $choice in
            1)
                install_node_client "节点"
                ;;
            2)
                install_node_client "客户端"
                ;;
            3)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                    sudo systemctl start "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已启动${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            4)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                    sudo systemctl stop "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已停止${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            5)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务已重启${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            6)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在卸载节点/客户端...${NC}"
                    
                    # 停止服务
                    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
                    
                    # 卸载服务
                    sudo "$BINARY_PATH" uninstall
                    
                    # 删除文件
                    sudo rm -f "$BINARY_PATH"
                    
                    # 禁用服务
                    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
                    
                    echo -e "${GREEN}✓ 节点/客户端已卸载${NC}"
                else
                    echo -e "${RED}节点/客户端未安装${NC}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        
        echo ""
        read -p "$(echo -e "${BLUE}按Enter键继续...${NC}")" 
    done
}

# 主菜单
main_menu() {
    # 首次运行安装工具箱
    if [ ! -f "$TOOLBOX_PATH" ]; then
        install_toolbox
        echo ""
        echo -e "${YELLOW}工具箱安装完成! 请使用 'gotool' 命令运行工具箱${NC}"
        exit 0
    fi
    
    while true; do
        # 显示主菜单
        echo ""
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║             ${WHITE}GOSTC 服务管理工具箱 ${PURPLE}             ║"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  版本: ${WHITE}$TOOLBOX_VERSION${PURPLE}                             ║"
        echo -e "║  命令: ${WHITE}gotool${PURPLE}                                  ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}请选择操作类型:${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理"
        echo -e "${CYAN}3. ${WHITE}更新工具箱"
        echo -e "${CYAN}4. ${WHITE}卸载工具箱"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo ""

        read -rp "请输入选项 (0-4): " choice
        
        case $choice in
            1)
                manage_server
                ;;
            2)
                manage_node_client
                ;;
            3)
                update_toolbox
                ;;
            4)
                uninstall_toolbox
                ;;
            0)
                echo -e "${BLUE}▶ 感谢使用GOSTC工具箱${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
    done
}

# 启动主菜单
main_menu
