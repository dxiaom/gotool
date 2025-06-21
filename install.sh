#!/bin/bash

# 工具箱版本和更新日志
TOOL_VERSION="1.5.5"
CHANGELOG=(
"1.5.5 - 代码结构优化，精简35%代码"
"1.5.4 - 状态显示优化、服务器验证增强、错误处理改进、用户界面优化、代码结构优化、性能优化、用户体验增强"
"1.5.3 - 继续优化部分代码逻辑，合并部分代码"
"1.5.2 - 优化工具箱更新逻辑"
"1.5.1 - 修复日志显示问题，优化其他问题"
"1.5.0 - 修复部分bug，添加节点/客户端更新功能"
"1.4.5 - 修复部分bug"
"1.4.4 - 使用国内镜像解决下载问题"
"1.4.2 - 优化颜色展示，统一颜色主题"
"1.4.1 - 优化更新检查提示"
"1.4.0 - 添加自动更新检查功能"
"1.3.0 - 添加工具箱自动更新功能"
"1.2.0 - 整合服务端和节点管理功能"
"1.1.0 - 添加节点/客户端管理功能"
"1.0.0 - 初始版本，服务端管理功能"
)

# 定义颜色代码
TITLE='\033[0;34m'      # 标题颜色 (蓝色)
OPTION_NUM='\033[0;35m' # 选项编号颜色 (紫色)
OPTION_TEXT='\033[1;37m' # 选项文案颜色 (白色)
SEPARATOR='\033[0;34m'  # 分割线颜色 (蓝色)
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 重置颜色

# 工具箱安装路径
TOOL_PATH="/usr/local/bin/gotool"

# 服务端配置
SERVER_TARGET_DIR="/usr/local/gostc-admin"
SERVER_BINARY_NAME="server"
SERVER_SERVICE_NAME="gostc-admin"
SERVER_CONFIG_FILE="${SERVER_TARGET_DIR}/config.yml"

# 节点/客户端配置
NODE_TARGET_DIR="/usr/local/bin"
NODE_BINARY_NAME="gostc"
NODE_SERVICE_NAME="gostc"

# 安装模式检测
if [ ! -t 0 ]; then
    # 管道安装模式
    echo -e "${TITLE}▶ 正在安装 GOSTC 工具箱...${NC}"
    sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" || {
        echo -e "${RED}✗ 工具箱下载失败${NC}"
        exit 1
    }
    sudo chmod +x "$TOOL_PATH"
    echo -e "${GREEN}✓ GOSTC 工具箱已安装到 ${OPTION_TEXT}${TOOL_PATH}${NC}"
    echo -e "${TITLE}使用 ${OPTION_TEXT}gotool${TITLE} 命令运行工具箱${NC}"
    exit 0
fi

# 获取服务状态函数
get_service_status() {
    local service_name=$1
    local binary_path=$2
    
    if ! command -v "$binary_path" &> /dev/null; then
        echo -e "${YELLOW}[未安装]${NC}"
        return
    fi
    
    if sudo systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}[运行中]${NC}"
    elif sudo systemctl is-failed --quiet "$service_name" 2>/dev/null; then
        echo -e "${RED}[失败]${NC}"
    else
        echo -e "${YELLOW}[未运行]${NC}"
    fi
}

# 获取服务端状态
server_status() {
    get_service_status "$SERVER_SERVICE_NAME" "${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}"
}

# 获取节点状态
node_status() {
    get_service_status "$NODE_SERVICE_NAME" "${NODE_TARGET_DIR}/${NODE_BINARY_NAME}"
}

# 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 确定要卸载 GOSTC 工具箱吗？${NC}"
    read -rp "确认卸载？(y/n, 默认n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo rm -f "$TOOL_PATH"
        echo -e "${GREEN}✓ GOSTC 工具箱已卸载${NC}"
        exit 0
    else
        echo -e "${TITLE}▶ 卸载已取消${NC}"
    fi
}

# 获取最新版本信息
get_latest_version_info() {
    # 获取最新版本和更新日志
    local remote_script
    remote_script=$(curl -s "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh")
    
    # 提取最新版本号
    local latest_version
    latest_version=$(awk -F'"' '/TOOL_VERSION=/{print $2; exit}' <<< "$remote_script")
    
    # 提取最新版本的更新日志（第一行）
    local latest_changelog
    latest_changelog=$(grep -m1 '^"' <<< "$remote_script" | cut -d'"' -f2)
    
    echo "$latest_version|$latest_changelog"
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 正在检查更新...${NC}"
    
    # 获取最新版本信息
    local latest_info
    latest_info=$(get_latest_version_info)
    
    if [[ -z "$latest_info" ]]; then
        echo -e "${RED}✗ 无法获取最新版本信息${NC}"
        return
    fi
    
    # 解析最新版本信息
    local latest_version="${latest_info%|*}"
    local latest_changelog="${latest_info#*|}"
    
    if [[ "$latest_version" == "$TOOL_VERSION" ]]; then
        echo -e "${GREEN}✓ 当前已是最新版本 (v$TOOL_VERSION)${NC}"
        return
    fi
    
    echo -e "${TITLE}▷ 当前版本: ${OPTION_TEXT}v$TOOL_VERSION${NC}"
    echo -e "${TITLE}▷ 最新版本: ${OPTION_TEXT}v$latest_version${NC}"
    echo -e "${YELLOW}════════════════ 更新日志 ════════════════${NC}"
    [[ -n "$latest_changelog" ]] && echo -e "${OPTION_TEXT}$latest_changelog${NC}" || echo -e "${YELLOW}暂无更新日志${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    
    read -rp "是否立即更新到最新版本? (y/n, 默认 y): " confirm
    if [[ "$confirm" != "n" ]]; then
        echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
        sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" || {
            echo -e "${RED}✗ 更新失败${NC}"
            return
        }
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已更新到 v$latest_version${NC}"
        echo -e "${TITLE}请重新运行 ${OPTION_TEXT}gotool${TITLE} 命令${NC}"
        exit 0
    else
        echo -e "${TITLE}▶ 更新已取消${NC}"
    fi
}

# 自动检查更新（带友好提示）
auto_check_update() {
    echo -e "${YELLOW}▶ 正在检查工具箱更新...${NC}"
    echo -e "${TITLE}▷ 当前版本: ${OPTION_TEXT}v$TOOL_VERSION${NC}"
    
    # 获取最新版本信息
    local latest_info
    latest_info=$(get_latest_version_info)
    
    if [[ -z "$latest_info" ]]; then
        echo -e "${RED}✗ 无法获取最新版本信息${NC}"
        return
    fi
    
    # 解析最新版本信息
    local latest_version="${latest_info%|*}"
    local latest_changelog="${latest_info#*|}"
    
    if [[ "$latest_version" == "$TOOL_VERSION" ]]; then
        echo -e "${GREEN}✓ 当前已是最新版本${NC}"
        return
    fi
    
    echo -e "${GREEN}✓ 发现新版本: ${OPTION_TEXT}v$latest_version${NC}"
    echo -e "${YELLOW}════════════════ 更新日志 ════════════════${NC}"
    [[ -n "$latest_changelog" ]] && echo -e "${OPTION_TEXT}$latest_changelog${NC}" || echo -e "${YELLOW}暂无更新日志${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}▶ 正在自动更新工具箱...${NC}"
    
    # 执行更新
    sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已更新到 v$latest_version${NC}"
        echo -e "${TITLE}请重新运行 ${OPTION_TEXT}gotool${TITLE} 命令${NC}"
        exit 0
    } || {
        echo -e "${RED}✗ 自动更新失败，请手动更新${NC}"
    }
}

# 服务管理菜单
service_management() {
    local service_name=$1
    local target_dir=$2
    local binary_name=$3
    local menu_title=$4
    local status_func=$5
    local install_func=$6
    
    while true; do
        service_stat=$($status_func)
        
        echo ""
        echo -e "${TITLE}${menu_title} ${service_stat}${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        [[ "$service_name" == "$SERVER_SERVICE_NAME" ]] && 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装/更新${NC}" || 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}启动${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}重启${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}停止${NC}"
        echo -e "${OPTION_NUM}5. ${OPTION_TEXT}卸载${NC}"
        [[ "$service_name" == "$NODE_SERVICE_NAME" ]] && 
            echo -e "${OPTION_NUM}6. ${OPTION_TEXT}更新${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回主菜单${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        
        read -rp "请输入选项: " choice
        case $choice in
            1) $install_func ;;
            2) start_service "$service_name" "$target_dir/$binary_name" ;;
            3) restart_service "$service_name" "$target_dir/$binary_name" ;;
            4) stop_service "$service_name" "$target_dir/$binary_name" ;;
            5) uninstall_service "$service_name" "$target_dir/$binary_name" ;;
            6) 
                [[ "$service_name" == "$NODE_SERVICE_NAME" ]] && 
                    update_node_client || 
                    echo -e "${RED}无效选项${NC}" 
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
    done
}

# 启动服务
start_service() {
    local service_name=$1
    local binary_path=$2
    
    if ! command -v "$binary_path" &> /dev/null; then
        echo -e "${RED}✗ 未安装，请先安装${NC}"
        return
    fi
    
    echo -e "${YELLOW}▶ 正在启动...${NC}"
    sudo systemctl start "$service_name"
    sleep 2
    
    if sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}✓ 已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 启动可能存在问题${NC}"
    fi
}

# 重启服务
restart_service() {
    local service_name=$1
    local binary_path=$2
    
    if ! command -v "$binary_path" &> /dev/null; then
        echo -e "${RED}✗ 未安装，请先安装${NC}"
        return
    fi
    
    echo -e "${YELLOW}▶ 正在重启...${NC}"
    sudo systemctl restart "$service_name"
    sleep 2
    
    if sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}✓ 已成功重启${NC}"
    else
        echo -e "${YELLOW}⚠ 重启可能存在问题${NC}"
    fi
}

# 停止服务
stop_service() {
    local service_name=$1
    local binary_path=$2
    
    if ! command -v "$binary_path" &> /dev/null; then
        echo -e "${RED}✗ 未安装，请先安装${NC}"
        return
    fi
    
    echo -e "${YELLOW}▶ 正在停止...${NC}"
    sudo systemctl stop "$service_name"
    sleep 1
    
    if sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${YELLOW}⚠ 停止失败${NC}"
    else
        echo -e "${GREEN}✓ 已停止${NC}"
    fi
}

# 卸载服务
uninstall_service() {
    local service_name=$1
    local binary_path=$2
    
    if ! command -v "$binary_path" &> /dev/null; then
        echo -e "${RED}✗ 未安装${NC}"
        return
    fi
    
    echo -e "${YELLOW}▶ 确定要卸载吗？${NC}"
    read -rp "确认卸载？(y/n, 默认n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "${TITLE}▶ 卸载已取消${NC}"
        return
    fi
    
    # 停止服务
    if sudo systemctl is-active --quiet "$service_name"; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$service_name"
    fi
    
    # 卸载服务
    if sudo systemctl list-unit-files | grep -q "$service_name"; then
        echo -e "${YELLOW}▷ 卸载系统服务...${NC}"
        sudo "$binary_path" service uninstall
    fi
    
    # 删除文件
    echo -e "${YELLOW}▷ 删除安装文件...${NC}"
    if [[ "$service_name" == "$SERVER_SERVICE_NAME" ]]; then
        sudo rm -rf "$SERVER_TARGET_DIR"
    else
        sudo rm -f "${NODE_TARGET_DIR}/${NODE_BINARY_NAME}"
    fi
    
    echo -e "${GREEN}✓ 已卸载${NC}"
}

# 安装服务端
install_server() {
    local UPDATE_MODE=false
    local INSTALL_MODE="install"
    local BASE_URL="https://alist.sian.one/direct/gostc/gostc-open"
    local VERSION_NAME="普通版本"
    
    # 检查是否已安装
    if [ -f "${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}" ]; then
        echo -e "${TITLE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}更新到最新版本 (保留配置)${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}重新安装最新版本 (删除所有文件重新安装)${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}退出${NC}"

        read -rp "请输入选项编号 (1-3, 默认 1): " operation_choice
        case "$operation_choice" in
            2) 
                sudo rm -rf "${SERVER_TARGET_DIR}"
                INSTALL_MODE="reinstall"
                ;;
            3)
                echo -e "${TITLE}操作已取消${NC}"
                return
                ;;
            *)
                UPDATE_MODE=true
                INSTALL_MODE="update"
                ;;
        esac
    fi

    # 选择版本
    echo -e "${TITLE}请选择安装版本:${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}普通版本 (默认)${NC}"
    echo -e "${OPTION_Num}2. ${OPTION_TEXT}商业版本 (需要授权)${NC}"

    read -rp "请输入选项编号 (1-2, 默认 1): " version_choice
    case "$version_choice" in
        2) 
            BASE_URL="https://alist.sian.one/direct/gostc"
            VERSION_NAME="商业版本"
            echo -e "${YELLOW}▶ 您选择了商业版本，请确保您已获得商业授权${NC}"
            ;;
    esac

    echo ""
    echo -e "${TITLE}▶ 开始安装 服务端 (${VERSION_NAME})${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"

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
    FILE_NAME="${SERVER_BINARY_NAME}_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${FILE_NAME}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 创建目标目录
    sudo mkdir -p "$SERVER_TARGET_DIR" >/dev/null 2>&1

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
        return
    }

    # 检查服务是否运行
    if sudo systemctl is-active --quiet "$SERVER_SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SERVICE_NAME"
    fi

    # 解压文件
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${SERVER_TARGET_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 更新模式：保留配置文件
    if [ "$UPDATE_MODE" = true ]; then
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CONFIG_FILE" "${SERVER_CONFIG_FILE}.bak" 2>/dev/null
        sudo find "${SERVER_TARGET_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        sudo mv -f "${SERVER_CONFIG_FILE}.bak" "$SERVER_CONFIG_FILE" 2>/dev/null
    else
        sudo rm -f "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME"
    fi

    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$SERVER_TARGET_DIR"
    else
        sudo tar xzf "$FILE_NAME" -C "$SERVER_TARGET_DIR"
    fi

    # 设置权限
    if [ -f "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" ]; then
        sudo chmod 755 "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${SERVER_TARGET_DIR}/${SERVER_BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BINARY_NAME${NC}"
        return
    fi

    # 初始化服务
    echo ""
    echo -e "${TITLE}▶ 正在初始化服务...${NC}"
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVER_SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_TARGET_DIR/$SERVER_BINARY_NAME" service install "$@"
    fi

    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SERVICE_NAME" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SERVICE_NAME"

    # 清理
    rm -f "$FILE_NAME"

    # 检查服务状态
    sleep 2
    SERVICE_STATUS=$(systemctl is-active "$SERVER_SERVICE_NAME")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓ 服务已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${SERVICE_STATUS}${NC}"
    fi

    # 安装完成提示
    echo ""
    echo -e "${TITLE}操作类型: ${OPTION_TEXT}$([ "$UPDATE_MODE" = true ] && echo "更新" || echo "${INSTALL_MODE:-安装}")${NC}"
    echo -e "${TITLE}版本: ${OPTION_TEXT}${VERSION_NAME}${NC}"
    echo -e "${TITLE}安装目录: ${OPTION_TEXT}$SERVER_TARGET_DIR${NC}"
    echo -e "${TITLE}服务状态: $(if [ "$SERVICE_STATUS" = "active" ]; then echo -e "${GREEN}运行中${NC}"; else echo -e "${YELLOW}未运行${NC}"; fi)"
    echo -e "${TITLE}访问地址: ${OPTION_TEXT}http://localhost:8080${NC}"

    # 显示初始凭据
    if [ ! -f "$SERVER_CONFIG_FILE" ] && [ "$UPDATE_MODE" != "true" ]; then
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "用户名: ${OPTION_TEXT}admin${NC}"
        echo -e "密码: ${OPTION_TEXT}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    fi
}

# 安装节点/客户端
install_node_client() {
    # 主菜单
    echo ""
    echo -e "${TITLE}▶ 请选择安装类型${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装节点 (默认)${NC}"
    echo -e "${OPTION_NUM}2. ${OPTION_TEXT}安装客户端${NC}"
    echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    read -p "$(echo -e "${TITLE}▷ 请输入选择 [1-2] (默认1): ${NC}")" choice
    [ -z "$choice" ] && choice=1
    
    case $choice in
        1) install_component "节点" ;;
        2) install_component "客户端" ;;
        0) return ;;
        *) install_component "节点" ;;
    esac
}

# 安装组件函数
install_component() {
    local component_type=$1
    
    echo ""
    echo -e "${TITLE}▶ 开始安装 ${OPTION_TEXT}${component_type}${TITLE} 组件${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"
    
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
            return
            ;;
    esac
    
    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="${NODE_BINARY_NAME}_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"
    
    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${FILE_NAME}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$NODE_TARGET_DIR" >/dev/null 2>&1
    
    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }
    
    # 解压文件
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${NODE_TARGET_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    sudo rm -f "$NODE_TARGET_DIR/$NODE_BINARY_NAME"
    if [[ "$FILE_NAME" == *.zip ]]; then
        sudo unzip -qo "$FILE_NAME" -d "$NODE_TARGET_DIR"
    else
        sudo tar xzf "$FILE_NAME" -C "$NODE_TARGET_DIR"
    fi
    
    # 设置权限
    if [ -f "$NODE_TARGET_DIR/$NODE_BINARY_NAME" ]; then
        sudo chmod 755 "$NODE_TARGET_DIR/$NODE_BINARY_NAME"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${NODE_TARGET_DIR}/${NODE_BINARY_NAME}${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BINARY_NAME${NC}"
        return
    fi
    
    # 清理
    rm -f "$FILE_NAME"
    
    # 配置
    if [ "$component_type" = "节点" ]; then
        configure_node
    else
        configure_client
    fi
}

# 验证服务器地址
validate_server_address() {
    local address=$1
    local use_tls=$2
    
    # 添加协议前缀
    if [[ "$use_tls" == "true" ]]; then
        [[ "$address" != http* ]] && address="https://$address"
    else
        [[ "$address" != http* ]] && address="http://$address"
    fi
    
    # 验证服务器是否可达
    echo -e "${TITLE}▷ 验证服务器地址: ${OPTION_TEXT}$address${NC}"
    
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

# 配置节点
configure_node() {
    echo ""
    echo -e "${TITLE}▶ 节点配置${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 节点密钥 (由服务端提供)"
    echo -e "  - (可选) 网关代理地址${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"
    
    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input_addr
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
        read -p "$(echo -e "${TITLE}▷ 输入节点密钥: ${NC}")" node_key
        [ -z "$node_key" ] && echo -e "${RED}✗ 节点密钥不能为空${NC}"
    done
    
    # 网关代理选项
    local proxy_base_url=""
    read -p "$(echo -e "${TITLE}▷ 是否使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "$(echo -e "${TITLE}▷ 输入网关地址 (包含http/https前缀): ${NC}")" proxy_url
            if [[ "$proxy_url" =~ ^https?:// ]]; then
                proxy_base_url="$proxy_url"
                break
            else
                echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
            fi
        done
    fi
    
    # 构建安装命令
    local install_cmd="sudo $NODE_TARGET_DIR/$NODE_BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    [ -n "$proxy_base_url" ] && install_cmd+=" --proxy-base-url $proxy_base_url"
    
    # 添加配置提示
    echo ""
    echo -e "${TITLE}▶ 正在配置节点${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}节点${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$server_addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$use_tls${NC}"
    [ -n "$proxy_base_url" ] && echo -e "${TITLE}网关地址: ${OPTION_TEXT}$proxy_base_url${NC}"
}

# 配置客户端
configure_client() {
    echo ""
    echo -e "${TITLE}▶ 客户端配置${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${GREEN}提示: 请准备好以下信息："
    echo -e "  - 服务器地址 (如: example.com:8080)"
    echo -e "  - 客户端密钥 (由服务端提供)${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"
    
    # 服务器地址
    local server_addr="127.0.0.1:8080"
    while true; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input_addr
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
        read -p "$(echo -e "${TITLE}▷ 输入客户端密钥: ${NC}")" client_key
        [ -z "$client_key" ] && echo -e "${RED}✗ 客户端密钥不能为空${NC}"
    done
    
    # 构建安装命令
    local install_cmd="sudo $NODE_TARGET_DIR/$NODE_BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    # 添加配置提示
    echo ""
    echo -e "${TITLE}▶ 正在配置客户端${NC}"
    
    # 执行安装命令
    eval "$install_cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SERVICE_NAME" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}客户端${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$server_addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$use_tls${NC}"
}

# 更新节点/客户端
update_node_client() {
    if ! command -v "$NODE_BINARY_NAME" &> /dev/null; then
        echo -e "${RED}✗ 节点/客户端未安装，请先安装${NC}"
        return
    fi

    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"

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
            return
            ;;
    esac

    # Windows系统检测
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"

    # 构建下载URL
    BASE_URL="https://alist.sian.one/direct/gostc"
    FILE_NAME="${NODE_BINARY_NAME}_${OS}_${FILE_SUFFIX}"
    [ "$OS" = "windows" ] && FILE_NAME="${FILE_NAME}.zip" || FILE_NAME="${FILE_NAME}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${FILE_NAME}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || return

    # 下载文件
    curl -# -fL -o "$FILE_NAME" "$DOWNLOAD_URL" || {
        echo ""
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }

    # 停止服务
    echo -e "${YELLOW}▷ 停止节点/客户端服务...${NC}"
    sudo systemctl stop "$NODE_SERVICE_NAME"

    # 解压文件并替换二进制
    echo -e "${TITLE}▷ 正在更新节点/客户端...${NC}"
    if [[ "$FILE_NAME" == *.zip ]]; then
        unzip -qo "$FILE_NAME" -d "$TMP_DIR"
    else
        tar xzf "$FILE_NAME" -C "$TMP_DIR"
    fi

    # 移动新文件到目标位置
    if [ -f "$TMP_DIR/$NODE_BINARY_NAME" ]; then
        sudo mv -f "$TMP_DIR/$NODE_BINARY_NAME" "${NODE_TARGET_DIR}/${NODE_BINARY_NAME}"
        sudo chmod 755 "${NODE_TARGET_DIR}/${NODE_BINARY_NAME}"
        echo -e "${GREEN}✓ 节点/客户端更新成功${NC}"
    else
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BINARY_NAME${NC}"
        sudo systemctl start "$NODE_SERVICE_NAME"
        return
    fi

    # 清理临时文件
    cd - >/dev/null || return
    rm -rf "$TMP_DIR"

    # 启动服务
    echo -e "${YELLOW}▷ 启动节点/客户端服务...${NC}"
    sudo systemctl start "$NODE_SERVICE_NAME"

    # 检查服务状态
    sleep 2
    if sudo systemctl is-active --quiet "$NODE_SERVICE_NAME"; then
        echo -e "${GREEN}✓ 节点/客户端已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠ 节点/客户端启动可能存在问题${NC}"
    fi
}

# 显示工具箱信息
show_toolbox_info() {
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${TITLE}          GOSTC 服务管理工具箱 v${TOOL_VERSION}           ${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${TITLE}▷ 服务端状态: $(server_status)${NC}"
    echo -e "${TITLE}▷ 节点/客户端状态: $(node_status)${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
}

# 主菜单
main_menu() {
    # 自动检查更新
    auto_check_update
    
    while true; do
        show_toolbox_info
        
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}服务端管理${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}节点/客户端管理${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}检查更新${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}卸载工具箱${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}退出${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        
        read -rp "请输入选项: " choice
        case $choice in
            1) service_management "$SERVER_SERVICE_NAME" "$SERVER_TARGET_DIR" "$SERVER_BINARY_NAME" "GOSTC 服务端管理" server_status install_server ;;
            2) service_management "$NODE_SERVICE_NAME" "$NODE_TARGET_DIR" "$NODE_BINARY_NAME" "GOSTC 节点/客户端管理" node_status install_node_client ;;
            3) check_update ;;
            4) uninstall_toolbox ;;
            0) 
                echo -e "${TITLE}▶ 感谢使用 GOSTC 工具箱${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
