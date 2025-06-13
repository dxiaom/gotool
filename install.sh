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

# 脚本信息
SCRIPT_VERSION="1.0.1"
SCRIPT_NAME="gotool"
INSTALL_PATH="/usr/local/bin/$SCRIPT_NAME"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh"

# 安装自身到系统
install_self() {
    echo -e "${YELLOW}▶ 正在安装工具箱到系统...${NC}"
    sudo curl -# -fL "$REMOTE_SCRIPT_URL" -o "$INSTALL_PATH" || {
        echo -e "${RED}✗ 工具箱安装失败!${NC}"
        exit 1
    }
    sudo chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}✓ 工具箱已安装到: ${WHITE}$INSTALL_PATH${NC}"
    echo -e "${GREEN}✓ 请使用命令 ${WHITE}$SCRIPT_NAME${GREEN} 运行工具箱${NC}"
    exit 0
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 检查脚本更新...${NC}"
    remote_version=$(curl -sSf "$REMOTE_SCRIPT_URL" | grep -m1 "SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        echo -e "${YELLOW}发现新版本: $remote_version (当前: $SCRIPT_VERSION)${NC}"
        read -p "$(echo -e "${BLUE}是否更新到最新版本? (y/n, 默认y): ${NC}")" update_choice
        if [[ ! "$update_choice" =~ ^[Nn]$ ]]; then
            sudo curl -# -fL "$REMOTE_SCRIPT_URL" -o "$0" || {
                echo -e "${RED}✗ 更新失败!${NC}"
                return
            }
            chmod +x "$0"
            echo -e "${GREEN}✓ 已更新到最新版本${NC}"
            echo -e "${YELLOW}请重新运行脚本${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ 已是最新版本${NC}"
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

# 服务端安装
install_server() {
    # 打印标题
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务端安装向导${PURPLE}              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

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
                echo -e "${YELLOW}▶ 开始重新安装服务端...${NC}"
                sudo rm -rf "${TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                echo -e "${BLUE}操作已取消${NC}"
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
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return
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
        return
    fi

    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return
    fi

    # 初始化服务
    echo ""
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install "$@"
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

    # 显示初始凭据（仅在新安装或重新安装时显示）
    if [ ! -f "$CONFIG_FILE" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
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
    TARGET_DIR="/usr/local/gostc-admin"
    BINARY_NAME="server"
    SERVICE_NAME="gostc-admin"
    
    while true; do
        # 检查服务状态
        SERVICE_STATUS="未安装"
        if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                SERVICE_STATUS="${GREEN}运行中${NC}"
            else
                SERVICE_STATUS="${YELLOW}已停止${NC}"
            fi
        fi
        
        clear
        echo -e "${PURPLE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║              ${WHITE}GOSTC 服务端管理${PURPLE}               ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  服务状态: $SERVICE_STATUS                          ║"
        echo -e "║  安装路径: ${WHITE}$TARGET_DIR${PURPLE}               ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${PURPLE} ${WHITE}安装/更新服务端${PURPLE}                          ║"
        echo -e "║  ${CYAN}2.${PURPLE} ${WHITE}启动服务${PURPLE}                                ║"
        echo -e "║  ${CYAN}3.${PURPLE} ${WHITE}停止服务${PURPLE}                                ║"
        echo -e "║  ${CYAN}4.${PURPLE} ${WHITE}重启服务${PURPLE}                                ║"
        echo -e "║  ${CYAN}5.${PURPLE} ${WHITE}卸载服务${PURPLE}                                ║"
        echo -e "║  ${CYAN}0.${PURPLE} ${WHITE}返回主菜单${PURPLE}                              ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请输入操作编号 (0-5): " choice
        
        case $choice in
            1)
                install_server
                ;;
            2)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                sudo systemctl start "$SERVICE_NAME"
                sleep 2
                ;;
            3)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo systemctl stop "$SERVICE_NAME"
                sleep 2
                ;;
            4)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                sudo systemctl restart "$SERVICE_NAME"
                sleep 2
                ;;
            5)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                    sleep 2
                    continue
                fi
                
                echo -e "${RED}警告: 此操作将完全卸载服务端!${NC}"
                read -p "确认卸载? (y/n, 默认n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
                    
                    echo -e "${YELLOW}▶ 正在卸载服务...${NC}"
                    sudo "${TARGET_DIR}/${BINARY_NAME}" service uninstall 2>/dev/null
                    
                    echo -e "${YELLOW}▶ 正在删除文件...${NC}"
                    sudo rm -rf "$TARGET_DIR"
                    
                    echo -e "${GREEN}✓ 服务端已完全卸载${NC}"
                    sleep 2
                else
                    echo -e "${BLUE}操作已取消${NC}"
                    sleep 1
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 安装节点/客户端组件
install_component() {
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
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return 1
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
        return 1
    fi
    
    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
        return 0
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi
    
    # 清理
    rm -f "$FILE_NAME"
}

# 安装节点
install_node() {
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    if ! install_component "节点"; then
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
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
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
}

# 安装客户端
install_client() {
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    if ! install_component "客户端"; then
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
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${BLUE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${BLUE}▶ 正在启动服务${NC}"
    sudo systemctl start "$SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
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
}

# 节点/客户端管理
manage_client() {
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    while true; do
        # 检查服务状态
        SERVICE_STATUS="未安装"
        if [ -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                SERVICE_STATUS="${GREEN}运行中${NC}"
            else
                SERVICE_STATUS="${YELLOW}已停止${NC}"
            fi
        fi
        
        clear
        echo -e "${BLUE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║            ${WHITE}GOSTC 节点/客户端管理${BLUE}            ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  服务状态: $SERVICE_STATUS                          ║"
        echo -e "║  安装路径: ${WHITE}$TARGET_DIR${BLUE}                      ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${BLUE} ${WHITE}安装节点${BLUE}                                  ║"
        echo -e "║  ${CYAN}2.${BLUE} ${WHITE}安装客户端${BLUE}                                ║"
        echo -e "║  ${CYAN}3.${BLUE} ${WHITE}启动服务${BLUE}                                  ║"
        echo -e "║  ${CYAN}4.${BLUE} ${WHITE}停止服务${BLUE}                                  ║"
        echo -e "║  ${CYAN}5.${BLUE} ${WHITE}重启服务${BLUE}                                  ║"
        echo -e "║  ${CYAN}6.${BLUE} ${WHITE}卸载服务${BLUE}                                  ║"
        echo -e "║  ${CYAN}0.${BLUE} ${WHITE}返回主菜单${BLUE}                                ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请输入操作编号 (0-6): " choice
        
        case $choice in
            1)
                install_node
                ;;
            2)
                install_client
                ;;
            3)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在启动服务...${NC}"
                sudo "$TARGET_DIR/$BINARY_NAME" start
                sleep 2
                ;;
            4)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo "$TARGET_DIR/$BINARY_NAME" stop
                sleep 2
                ;;
            5)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务未安装!${NC}"
                    sleep 2
                    continue
                fi
                echo -e "${YELLOW}▶ 正在重启服务...${NC}"
                sudo systemctl restart "$SERVICE_NAME"
                sleep 2
                ;;
            6)
                if [ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]; then
                    echo -e "${RED}错误: 服务未安装!${NC}"
                    sleep 2
                    continue
                fi
                
                echo -e "${RED}警告: 此操作将完全卸载服务!${NC}"
                read -p "确认卸载? (y/n, 默认n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                    sudo "$TARGET_DIR/$BINARY_NAME" stop 2>/dev/null
                    
                    echo -e "${YELLOW}▶ 正在卸载服务...${NC}"
                    sudo "$TARGET_DIR/$BINARY_NAME" uninstall 2>/dev/null
                    
                    echo -e "${YELLOW}▶ 正在删除文件...${NC}"
                    sudo rm -f "$TARGET_DIR/$BINARY_NAME"
                    
                    echo -e "${GREEN}✓ 服务已完全卸载${NC}"
                    sleep 2
                else
                    echo -e "${BLUE}操作已取消${NC}"
                    sleep 1
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 主菜单
main_menu() {
    # 首次运行检查
    if [ ! -f "$INSTALL_PATH" ]; then
        clear
        echo -e "${PURPLE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║             ${WHITE}GOSTC 工具箱安装向导${PURPLE}             ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e "${GREEN}首次运行，需要安装工具箱到系统${NC}"
        echo -e "${YELLOW}安装后您可以通过命令 ${WHITE}gotool${YELLOW} 在任何位置运行此工具箱${NC}"
        echo ""
        read -p "是否安装工具箱到系统? (y/n, 默认y): " choice
        if [[ ! "$choice" =~ ^[Nn]$ ]]; then
            install_self
        fi
    fi

    # 非首次运行检查更新
    check_update
    
    while true; do
        clear
        echo -e "${PURPLE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║               ${WHITE}GOSTC 工具箱 ${PURPLE} v$SCRIPT_VERSION            ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${PURPLE} ${WHITE}服务端管理${PURPLE}                              ║"
        echo -e "║  ${CYAN}2.${PURPLE} ${WHITE}节点/客户端管理${PURPLE}                         ║"
        echo -e "║  ${CYAN}3.${PURPLE} ${WHITE}更新工具箱${PURPLE}                             ║"
        echo -e "║  ${CYAN}0.${PURPLE} ${WHITE}退出${PURPLE}                                   ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-3): " choice
        
        case $choice in
            1)
                manage_server
                ;;
            2)
                manage_client
                ;;
            3)
                check_update
                sleep 2
                ;;
            0)
                echo -e "${BLUE}感谢使用，再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
