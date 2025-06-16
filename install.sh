#!/bin/bash

# GOSTC 工具箱管理脚本
VERSION="1.1.0"
CHANGELOG="
版本 1.1.0 (2024-06-16):
- 初始版本发布
- 整合服务端和客户端管理功能
- 添加工具箱自动更新功能
- 优化系统架构检测逻辑
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
TOOLBOX_PATH="/usr/local/bin/gotool"

# 检查是否通过管道安装
if [ ! -t 0 ]; then
    echo -e "${GREEN}正在安装GOSTC工具箱...${NC}"
    sudo cp "$0" "$TOOLBOX_PATH"
    sudo chmod +x "$TOOLBOX_PATH"
    echo -e "${GREEN}安装完成！请使用命令 ${WHITE}gotool ${GREEN}运行工具箱。${NC}"
    exit 0
fi

# 函数：获取系统信息
detect_system() {
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
        "riscv64")         FILE_SUFFIX="riscv64_rva20u64" ;;
        "s390x")           FILE_SUFFIX="s390x" ;;
        *)
            echo -e "${RED}错误: 不支持的架构: $ARCH${NC}"
            return 1
            ;;
    esac
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    echo "$OS $FILE_SUFFIX"
}

# 函数：检查服务状态
service_status() {
    local service_name=$1
    if ! sudo systemctl list-unit-files | grep -q "^${service_name}.service"; then
        echo -e "${YELLOW}[未安装]${NC}"
        return
    fi
    
    local status=$(sudo systemctl is-active "$service_name" 2>/dev/null)
    case "$status" in
        active)    echo -e "${GREEN}[运行中]${NC}" ;;
        failed)    echo -e "${RED}[失败]${NC}" ;;
        inactive)  echo -e "${YELLOW}[未运行]${NC}" ;;
        *)         echo -e "${YELLOW}[未知]${NC}" ;;
    esac
}

# 函数：安装服务端
install_server() {
    echo -e "${BLUE}▶ 开始安装服务端${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 配置参数
    TARGET_DIR="/usr/local/gostc-admin"
    BINARY_NAME="server"
    SERVICE_NAME="gostc-admin"
    CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    # 选择版本
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "${CYAN}1. ${WHITE}普通版本${BLUE} (默认)"
    echo -e "${CYAN}2. ${WHITE}商业版本${BLUE} (需要授权)${NC}"
    
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
    sys_info=$(detect_system)
    if [ $? -ne 0 ]; then
        return 1
    fi
    read -r OS FILE_SUFFIX <<< "$sys_info"
    
    # 构建下载URL
    FILE_NAME="server_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"
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
    
    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 解压文件
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
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi
    
    # 初始化服务
    echo -e "${BLUE}▶ 正在初始化服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 检查是否已安装服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install "$@"
    fi
    
    # 启动服务
    echo -e "${BLUE}▶ 正在启动服务...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVICE_NAME"
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 检查服务状态
    sleep 2
    echo -e "${BLUE}▶ 服务状态检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    SERVICE_STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
        echo -e "${YELLOW}请尝试手动启动: sudo systemctl restart ${SERVICE_NAME}${NC}"
    fi
    
    # 安装完成提示
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}安装完成${PURPLE}                   ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  版本: ${WHITE}${VERSION_NAME}${PURPLE}                             ║"
    echo -e "║  安装目录: ${WHITE}$TARGET_DIR${PURPLE}                     ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${PURPLE}"; else echo -e "${YELLOW}未运行${PURPLE}"; fi)                          ║"
    echo -e "║  访问地址: ${WHITE}http://localhost:8080${PURPLE}             ║"
    echo -e "║  管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${PURPLE} ║"
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 显示初始凭据
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin${NC}"
        echo -e "${CYAN}密码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
}

# 函数：服务端管理
manage_server() {
    SERVICE_NAME="gostc-admin"
    BINARY_PATH="/usr/local/gostc-admin/server"
    
    while true; do
        status=$(service_status "$SERVICE_NAME")
        
        echo ""
        echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
        echo -e "║              ${WHITE}GOSTC 服务端管理${PURPLE}              $status"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${NC} ${WHITE}安装服务端${NC}                             ║"
        echo -e "║  ${CYAN}2.${NC} ${WHITE}启动服务端${NC}                             ║"
        echo -e "║  ${CYAN}3.${NC} ${WHITE}重启服务端${NC}                             ║"
        echo -e "║  ${CYAN}4.${NC} ${WHITE}停止服务端${NC}                             ║"
        echo -e "║  ${CYAN}5.${NC} ${WHITE}卸载服务端${NC}                             ║"
        echo -e "║  ${CYAN}0.${NC} ${WHITE}返回主菜单${NC}                             ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        
        read -rp "请输入操作编号 (0-5): " choice
        
        case $choice in
            1)
                install_server
                ;;
            2)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在启动服务端...${NC}"
                    sudo "$BINARY_PATH" service start
                    sleep 1
                    echo -e "${GREEN}✓ 服务端已启动${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                fi
                ;;
            3)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在重启服务端...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 服务端已重启${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                fi
                ;;
            4)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在停止服务端...${NC}"
                    sudo "$BINARY_PATH" service stop
                    sleep 1
                    echo -e "${GREEN}✓ 服务端已停止${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                fi
                ;;
            5)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在卸载服务端...${NC}"
                    sudo "$BINARY_PATH" service uninstall
                    sudo rm -rf "/usr/local/gostc-admin"
                    echo -e "${GREEN}✓ 服务端已卸载${NC}"
                else
                    echo -e "${RED}错误: 服务端未安装!${NC}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入!${NC}"
                ;;
        esac
    done
}

# 函数：安装节点客户端
install_client() {
    echo -e "${BLUE}▶ 开始安装节点/客户端${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 配置参数
    TARGET_DIR="/usr/local/bin"
    BINARY_NAME="gostc"
    SERVICE_NAME="gostc"
    
    # 选择安装类型
    echo -e "${BLUE}请选择安装类型:${NC}"
    echo -e "${CYAN}1. ${WHITE}节点${BLUE} (默认)"
    echo -e "${CYAN}2. ${WHITE}客户端${NC}"
    
    read -rp "请输入选项编号 (1-2, 默认 1): " type_choice
    
    # 设置安装类型
    case "$type_choice" in
        2) 
            INSTALL_TYPE="客户端"
            ;;
        *)
            INSTALL_TYPE="节点"
            ;;
    esac
    
    # 获取系统信息
    sys_info=$(detect_system)
    if [ $? -ne 0 ]; then
        return 1
    fi
    read -r OS FILE_SUFFIX <<< "$sys_info"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="gostc_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${BLUE}▷ 检测系统: ${WHITE}${OS} ${ARCH}${NC}"
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
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $BINARY_NAME${NC}"
        return 1
    fi
    
    # 配置提示
    echo -e "${BLUE}▶ ${INSTALL_TYPE}配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - ${INSTALL_TYPE}密钥 (由服务端提供)"
    
    if [ "$INSTALL_TYPE" = "节点" ]; then
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
    read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
    [ -z "$input_addr" ] && input_addr="$server_addr"
    server_addr="$input_addr"
    
    # 密钥
    local node_key=""
    while [ -z "$node_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入${INSTALL_TYPE}密钥: ${NC}")" node_key
        if [ -z "$node_key" ]; then
            echo -e "${RED}✗ ${INSTALL_TYPE}密钥不能为空${NC}"
        fi
    done
    
    # 网关代理选项（仅节点）
    local proxy_base_url=""
    if [ "$INSTALL_TYPE" = "节点" ]; then
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
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr"
    
    if [ "$INSTALL_TYPE" = "节点" ]; then
        install_cmd="$install_cmd -s -key $node_key"
    else
        install_cmd="$install_cmd -key $node_key"
    fi
    
    if [ -n "$proxy_base_url" ]; then
        install_cmd="$install_cmd --proxy-base-url $proxy_base_url"
    fi
    
    # 执行安装命令
    echo -e "${BLUE}▶ 正在配置${INSTALL_TYPE}${NC}"
    eval "$install_cmd" || {
        echo -e "${RED}✗ ${INSTALL_TYPE}配置失败${NC}"
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
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                   ${WHITE}${INSTALL_TYPE}安装成功${BLUE}                  ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  组件: ${WHITE}${INSTALL_TYPE}${BLUE}                                   ║"
    echo -e "║  安装目录: ${WHITE}$TARGET_DIR${BLUE}                      ║"
    echo -e "║  服务器地址: ${WHITE}$server_addr${BLUE}                    ║"
    echo -e "║  TLS: ${WHITE}$use_tls${BLUE}                              ║"
    if [ -n "$proxy_base_url" ]; then
        echo -e "║  网关地址: ${WHITE}$proxy_base_url${BLUE}               ║"
    fi
    echo -e "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 清理
    rm -f "$FILE_NAME"
}

# 函数：节点/客户端管理
manage_client() {
    SERVICE_NAME="gostc"
    BINARY_PATH="/usr/local/bin/gostc"
    
    while true; do
        status=$(service_status "$SERVICE_NAME")
        
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
        echo -e "║            ${WHITE}GOSTC 节点/客户端管理${BLUE}            $status"
        echo -e "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${NC} ${WHITE}安装节点/客户端${NC}                       ║"
        echo -e "║  ${CYAN}2.${NC} ${WHITE}启动节点/客户端${NC}                       ║"
        echo -e "║  ${CYAN}3.${NC} ${WHITE}重启节点/客户端${NC}                       ║"
        echo -e "║  ${CYAN}4.${NC} ${WHITE}停止节点/客户端${NC}                       ║"
        echo -e "║  ${CYAN}5.${NC} ${WHITE}卸载节点/客户端${NC}                       ║"
        echo -e "║  ${CYAN}0.${NC} ${WHITE}返回主菜单${NC}                           ║"
        echo -e "╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        
        read -rp "请输入操作编号 (0-5): " choice
        
        case $choice in
            1)
                install_client
                ;;
            2)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在启动节点/客户端...${NC}"
                    sudo "$BINARY_PATH" start
                    sleep 1
                    echo -e "${GREEN}✓ 节点/客户端已启动${NC}"
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                fi
                ;;
            3)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在重启节点/客户端...${NC}"
                    sudo systemctl restart "$SERVICE_NAME"
                    sleep 1
                    echo -e "${GREEN}✓ 节点/客户端已重启${NC}"
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                fi
                ;;
            4)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${BLUE}▶ 正在停止节点/客户端...${NC}"
                    sudo "$BINARY_PATH" stop
                    sleep 1
                    echo -e "${GREEN}✓ 节点/客户端已停止${NC}"
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                fi
                ;;
            5)
                if [ -f "$BINARY_PATH" ]; then
                    echo -e "${YELLOW}▶ 正在卸载节点/客户端...${NC}"
                    sudo "$BINARY_PATH" uninstall
                    sudo rm -f "$BINARY_PATH"
                    echo -e "${GREEN}✓ 节点/客户端已卸载${NC}"
                else
                    echo -e "${RED}错误: 节点/客户端未安装!${NC}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入!${NC}"
                ;;
        esac
    done
}

# 函数：更新工具箱
update_toolbox() {
    echo -e "${BLUE}▶ 正在检查更新...${NC}"
    
    # 获取最新脚本
    TEMP_FILE=$(mktemp)
    curl -sSL https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh -o "$TEMP_FILE"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 更新检查失败${NC}"
        return 1
    fi
    
    # 获取最新版本
    NEW_VERSION=$(grep -m1 'VERSION=' "$TEMP_FILE" | cut -d'"' -f2)
    
    if [ "$NEW_VERSION" != "$VERSION" ]; then
        echo -e "${GREEN}发现新版本: $NEW_VERSION${NC}"
        echo -e "${YELLOW}更新日志:${NC}"
        grep -A10 'CHANGELOG=' "$TEMP_FILE" | sed -e '1d' -e 's/^"//' -e 's/"$//'
        
        read -p "$(echo -e "${BLUE}是否立即更新? (y/n): ${NC}")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo cp "$TEMP_FILE" "$TOOLBOX_PATH"
            sudo chmod +x "$TOOLBOX_PATH"
            echo -e "${GREEN}✓ 工具箱已更新到版本 $NEW_VERSION${NC}"
            echo -e "${GREEN}请重新运行 gotool 以使用新版本${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}当前已是最新版本 ($VERSION)${NC}"
    fi
    
    rm -f "$TEMP_FILE"
}

# 函数：卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 正在卸载GOSTC工具箱...${NC}"
    sudo rm -f "$TOOLBOX_PATH"
    echo -e "${GREEN}✓ 工具箱已卸载${NC}"
    echo -e "${BLUE}感谢您的使用，再见!${NC}"
    exit 0
}

# 主菜单
while true; do
    server_status=$(service_status "gostc-admin")
    client_status=$(service_status "gostc")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 工具箱 ${PURPLE}v$VERSION              ║"
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  ${CYAN}1.${NC} ${WHITE}服务端管理${NC} $server_status"
    echo -e "║  ${CYAN}2.${NC} ${WHITE}节点/客户端管理${NC} $client_status"
    echo -e "║  ${CYAN}3.${NC} ${WHITE}更新工具箱${NC}                          ║"
    echo -e "║  ${CYAN}4.${NC} ${WHITE}卸载工具箱${NC}                          ║"
    echo -e "║  ${CYAN}0.${NC} ${WHITE}退出${NC}                               ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -rp "请输入操作编号 (0-4): " main_choice
    
    case $main_choice in
        1)
            manage_server
            ;;
        2)
            manage_client
            ;;
        3)
            update_toolbox
            ;;
        4)
            uninstall_toolbox
            ;;
        0)
            echo -e "${BLUE}感谢使用GOSTC工具箱，再见!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入!${NC}"
            ;;
    esac
done
