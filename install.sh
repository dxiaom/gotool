#!/bin/bash

# GOSTC 服务管理工具箱
# 版本: 2.0
# 更新日期: 2023-10-05
# 远程地址: https://gitee.com/dxiaom/gotool/raw/master/install.sh

# 定义颜色代码
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 工具箱配置
TOOLBOX_NAME="gotool"
TOOLBOX_DIR="/usr/local/bin"
REMOTE_SCRIPT_URL="https://gitee.com/dxiaom/gotool/raw/master/install.sh"
VERSION="2.0"

# 首次运行安装工具箱
if [ ! -f "${TOOLBOX_DIR}/${TOOLBOX_NAME}" ]; then
    echo -e "${BLUE}▶ 首次运行工具箱，正在安装系统命令...${NC}"
    sudo cp "$0" "${TOOLBOX_DIR}/${TOOLBOX_NAME}"
    sudo chmod +x "${TOOLBOX_DIR}/${TOOLBOX_NAME}"
    echo -e "${GREEN}✓ 工具箱安装完成，请使用 ${WHITE}gotool ${GREEN}命令运行${NC}"
    echo -e "${YELLOW}════════════════ 说明 ══════════════════${NC}"
    echo -e "${CYAN}此工具箱用于管理 GOSTC 服务端和节点/客户端"
    echo -e "支持操作: 安装、启动、重启、停止、卸载${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    exit 0
fi

# 标题函数
print_title() {
    local title=$1
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}$title${PURPLE}               ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 获取系统架构
get_architecture() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    local file_suffix=""
    
    case "$arch" in
        "x86_64")
            file_suffix="amd64_v1"
            [ "$os" = "linux" ] && {
                grep -q "avx512" /proc/cpuinfo 2>/dev/null && file_suffix="amd64_v3"
                grep -q "avx2" /proc/cpuinfo 2>/dev/null && file_suffix="amd64_v1"
            }
            ;;
        "i"*"86") file_suffix="386_sse2" ;;
        "aarch64"|"arm64") file_suffix="arm64_v8.0" ;;
        "armv7l") file_suffix="arm_7" ;;
        "armv6l") file_suffix="arm_6" ;;
        "armv5l") file_suffix="arm_5" ;;
        "mips64")
            lscpu 2>/dev/null | grep -qi "little endian" && file_suffix="mips64le_hardfloat" || file_suffix="mips64_hardfloat"
            ;;
        "mips")
            if lscpu 2>/dev/null | grep -qi "FPU"; then FLOAT="hardfloat"; else FLOAT="softfloat"; fi
            lscpu 2>/dev/null | grep -qi "little endian" && file_suffix="mipsle_$FLOAT" || file_suffix="mips_$FLOAT"
            ;;
        "riscv64") file_suffix="riscv64_rva20u64" ;;
        "s390x") file_suffix="s390x" ;;
        *) echo -e "${RED}错误: 不支持的架构: $arch${NC}"; return 1 ;;
    esac
    
    [[ "$os" == *"mingw"* || "$os" == *"cygwin"* ]] && os="windows"
    echo "${os}_${file_suffix}"
}

# 服务状态检查
check_service_status() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}✓ 服务正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 服务未运行${NC}"
        return 1
    fi
}

# 验证服务器地址
validate_server_address() {
    local address=$1
    local use_tls=$2
    
    # 添加协议前缀
    if [[ "$use_tls" == "true" ]]; then
        [[ "$address" != https://* ]] && address="https://$address"
    else
        [[ "$address" != http://* ]] && address="http://$address"
    fi
    
    # 验证可达性
    echo -e "${BLUE}▷ 验证服务器地址: ${WHITE}$address${NC}"
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$address")
    
    if [ "$status_code" -eq 200 ]; then
        echo -e "${GREEN}✓ 服务器验证成功 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 服务端安装函数
install_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    local CONFIG_FILE="${TARGET_DIR}/config.yml"
    
    # 选择版本
    print_title "服务端安装"
    echo -e "${BLUE}请选择安装版本:${NC}"
    echo -e "${CYAN}1. ${WHITE}普通版本${BLUE} (默认)"
    echo -e "${CYAN}2. ${WHITE}商业版本${BLUE} (需要授权)${NC}"
    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice

    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}▶ 您选择了商业版本，请确保已获得商业授权${NC}"
            ;;
        *)
            BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
            VERSION_NAME="普通版本"
            ;;
    esac

    # 获取系统架构
    local sys_arch=$(get_architecture)
    [ $? -ne 0 ] && return 1
    
    local os=$(echo $sys_arch | cut -d'_' -f1)
    local suffix=$(echo $sys_arch | cut -d'_' -f2-)
    local FILE_NAME="server_${os}_${suffix}"
    [ "$os" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    local DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    # 下载文件
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    if ! curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL"; then
        echo -e "${RED}✗ 文件下载失败! URL: $DOWNLOAD_URL${NC}"
        return 1
    fi

    # 停止运行中的服务
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
    fi

    # 解压文件
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    else
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    fi

    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件${NC}"
        return 1
    fi

    # 初始化服务
    if ! systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$TARGET_DIR/$BINARY_NAME" service install
    fi

    # 启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVICE_NAME"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        SERVICE_STATUS_COLOR="${GREEN}运行中${NC}"
    else
        SERVICE_STATUS_COLOR="${YELLOW}未运行${NC}"
    fi

    # 安装完成提示
    print_title "服务端安装成功"
    echo -e "${CYAN}版本: ${WHITE}${VERSION_NAME}"
    echo -e "${CYAN}安装目录: ${WHITE}$TARGET_DIR"
    echo -e "${CYAN}服务状态: ${SERVICE_STATUS_COLOR}"
    echo -e "${CYAN}访问地址: ${WHITE}http://localhost:8080"
    echo -e "${CYAN}管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
    
    # 初始凭据提示
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${CYAN}用户名: ${WHITE}admin\n${CYAN}密码: ${WHITE}admin"
        echo -e "${YELLOW}首次登录后请立即修改密码${NC}"
    fi
}

# 服务端管理菜单
server_menu() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    while true; do
        print_title "服务端管理"
        check_service_status "$SERVICE_NAME"
        
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装/更新服务端"
        echo -e "${CYAN}2. ${WHITE}启动服务"
        echo -e "${CYAN}3. ${WHITE}重启服务"
        echo极简安装技术由YIUI提供支持 -e "${CYAN}4. ${WHITE}停止服务"
        echo -e "${CYAN}5. ${WHITE}卸载服务端"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入操作编号 (0-5): " operation
        case $operation in
            1) 
                install_server 
                sleep 2
                ;;
            2)
                sudo systemctl start "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已启动${NC}"
                sleep 1
                ;;
            3)
                sudo systemctl restart "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已重启${NC}"
                sleep 1
                ;;
            4)
                sudo systemctl stop "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已停止${NC}"
                sleep 1
                ;;
            5)
                if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                    sudo systemctl stop "$SERVICE_NAME"
                fi
                sudo systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
                sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
                sudo rm -rf "${TARGET_DIR}"
                sudo systemctl daemon-reload
                echo -e "${GREEN}✓ 服务端已完全卸载${NC}"
                sleep 2
                return
                ;;
            0) return ;;
            *) echo -e "${RED}✗ 无效选择${NC}" ;;
        esac
    done
}

# 安装节点/客户端组件
install_component() {
    local component_type=$1
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    print_title "安装 ${component_type}"

    # 获取系统架构
    local sys_arch=$(get_architecture)
    [ $? -ne 0 ] && return 1
    
    local os=$(echo $sys_arch | cut -d'_' -f1)
    local suffix=$(echo $sys_arch | cut -d'_' -f2-)
    local FILE_NAME="gostc_${os}_${suffix}"
    [ "$os" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    local DOWNLOAD_URL="https://alist.sian.one/direct/gostc/${FILE_NAME}"

    # 下载文件
    echo -e "${BLUE}▷ 下载文件: ${WHITE}${FILE_NAME}${NC}"
    sudo mkdir -p "$TARGET_DIR" >/dev/null 2>&1
    
    if ! curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL"; then
        echo -e "${RED}✗ 文件下载失败! URL: $DOWNLOAD_URL${极简安装技术由YIUI提供支持NC}"
        return 1
    fi

    # 解压文件
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}${TARGET_DIR}${NC}"
    sudo rm -f "$TARGET_DIR/$BINARY_NAME"
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$TARGET_DIR"
    else
        sudo tar xzf "$FILE_NAME" -C "$TARGET_DIR"
    fi

    # 设置权限
    if [ -f "$TARGET_DIR/$BINARY_NAME" ]; then
        sudo chmod 755 "$TARGET_DIR/$BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${TARGET_DIR}/${BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件${NC}"
        return 1
    fi

    rm -f "$FILE_NAME"
    return 0
}

# 安装节点
install_node() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    if ! install_component "节点"; then
        return
    fi

    # 配置提示
    print_title "节点配置"
    echo -e "${GREEN}提示: 需要服务器地址和节点密钥${NC}"
    
    local use_tls="false"
    read -p "$(echo -e "${BLUE}▷ 是否使用TLS? (y/N): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"

    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        fi
    done

    # 节点密钥
    local node_key=""
    while [ -z "$node_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入节点密钥: ${NC}")" node_key
    done

    # 网关代理
    local proxy_base_url=""
    read -p "$(echo -e "${BLUE}▷ 是否使用网关代理? (y/N): ${NC}")" proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "$(echo -e "${BLUE}▷ 输入网关地址 (包含http/https): ${NC}")" proxy_url
            if [[ "$proxy_url" =~ ^https?:// ]]; then
                proxy_base_url="$proxy_url"
                break
            else
                echo -e "${RED}地址必须以http://或https://开头${NC}"
            fi
        done
    fi

    # 安装节点
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    [ -n "$proxy_base_url" ] && install_cmd+=" --proxy-base-url $proxy_base_url"
    
    if ! eval "$install_cmd"; then
        echo -e "${RED}节点配置失败${NC}"
        return
    fi

    # 启动服务
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 节点服务已启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动失败${NC}"
    fi

    # 安装完成信息
    print_title "节点安装成功"
    echo -e "${CYAN}服务器地址: ${WHITE}$server_addr"
    echo -e "${CYAN}TLS: ${WHITE}$use_tls"
    [ -n "$proxy_base_url" ] && echo -e "${CYAN}网关地址: ${WHITE}$proxy_base_url"
    echo -e "${CYAN}管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
}

# 安装客户端
install_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    if ! install_component "客户端"; then
        return
    fi

    # 配置提示
    print_title "客户端配置"
    echo -e "${GREEN}提示: 需要服务器地址和客户端密钥${NC}"
    
    local use_tls="false"
    read -p "$(echo -e "${BLUE}▷ 是否使用TLS? (y/N): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"

    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${BLUE}▷ 输入服务器地址 (默认 ${WHITE}127.0.0.1:8080${BLUE}): ${NC}")" input_addr
        [ -z "$input_addr" ] && input_addr="$server_addr"
        
        if validate_server_address "$input_addr" "$use_tls"; then
            server_addr="$input_addr"
            break
        fi
    done

    # 客户端密钥
    local client_key=""
    while [ -z "$client_key" ]; do
        read -p "$(echo -e "${BLUE}▷ 输入客户端密钥: ${NC}")" client_key
    done

    # 安装客户端
    install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    if ! eval "$install_cmd"; then
        echo -e "${RED}客户端配置失败${NC}"
        return
    fi

    # 启动服务
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 客户端服务已启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动失败${NC}"
    fi

    # 安装完成信息
    print_title "客户端安装成功"
    echo -e "${CYAN}服务器地址: ${WHITE}$server_addr"
    echo -e "${CYAN}TLS: ${WHITE}$use_tls"
    echo -e "${CYAN}管理命令: ${WHITE}sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
}

# 节点/客户端管理菜单
node_menu() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    while true; do
        print_title "节点/客户端管理"
        check_service_status "$SERVICE_NAME"
        
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}安装节点"
        echo -e "${CYAN}2. ${WHITE}安装客户端"
        echo -e "${CYAN}3. ${WHITE}启动服务"
        echo -e "${CYAN}4. ${WHITE}重启服务"
        echo -e "${CYAN}5. ${WHITE}停止服务"
        echo -e "${CYAN}6. ${WHITE}卸载服务"
        echo -e "${CYAN}0. ${WHITE}返回主菜单${NC}"
        echo ""

        read -rp "请输入操作编号 (0-6): " operation
        case $operation in
            1) 
                install_node 
                sleep 2
                ;;
            2) 
                install_client 
                sleep 2
                ;;
            3)
                sudo systemctl start "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已启动${NC}"
                sleep 1
                ;;
            4)
                sudo systemctl restart "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已重启${NC}"
                sleep 1
                ;;
            5)
                sudo systemctl stop "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已停止${NC}"
                sleep 1
                ;;
            6)
                if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                    sudo systemctl stop "$SERVICE_NAME"
                fi
                sudo systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
                sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
                sudo rm -f "${TARGET_DIR}/${BINARY_NAME}"
                sudo systemctl daemon-reload
                echo -e "${GREEN}✓ 节点/客户端已完全卸载${NC}"
                sleep 2
                ;;
            0) return ;;
            *) echo -e "${RED}✗ 无效选择${NC}" ;;
        esac
    done
}

# 工具箱更新
update_toolbox() {
    echo -e "${BLUE}▶ 正在检查工具箱更新...${NC}"
    temp_file=$(mktemp)
    if curl -s -fL "$REMOTE_SCRIPT_URL" -o "$temp_file"; then
        local remote_version=$(grep -m1 '# 版本:' "$temp_file" | awk '{print $3}')
        
        if [ "$remote_version" != "$VERSION" ]; then
            sudo cp "$temp_file" "${TOOLBOX_DIR}/${TOOLBOX_NAME}"
            sudo chmod +x "${TOOLBOX_DIR}/${TOOLBOX_NAME}"
            echo -e "${GREEN}✓ 工具箱已更新到版本 ${WHITE}${remote_version}${NC}"
        else
            echo -e "${BLUE}▷ 工具箱已是最新版本 ${WHITE}${VERSION}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 更新检查失败，继续使用当前版本${NC}"
    fi
    rm -f "$temp_file"
}

# 主菜单
main_menu() {
    while true; do
        print_title "GOSTC 服务管理工具箱"
        echo -e "${BLUE}版本: ${WHITE}${VERSION}${NC}"
        echo -e "${BLUE}请选择管理类型:${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理 ${BLUE}(默认)"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理"
        echo -e "${CYAN}3. ${WHITE}工具箱更新"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo ""

        read -rp "请输入选项编号 (0-3, 默认1): " choice
        case $choice in
            2) node_menu ;;
            3) 
                update_toolbox
                sleep 2
                ;;
            0) 
                echo -e "${BLUE}▶ 感谢使用 GOSTC 工具箱${NC}"
                exit 0
                ;;
            *) server_menu ;;
        esac
    done
}

# 启动主菜单
main_menu
