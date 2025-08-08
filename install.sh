#!/bin/bash

# 工具箱版本和更新日志
TOOL_VERSION="1.7.2"
CHANGELOG=(
"1.7.2 - 优化国内访问"
"1.7.1 - 其他下版本号，啥也没更新好像是"
"1.7.0 - 极致代码精简、统一架构处理、菜单系统重构、用户交互优化、错误处理强化、服务操作统一、减少50%的系统调用、下载和安装流程合并、服务状态检测优化、避免不必要的临时文件"
"1.6.0 - 代码结构优化，精简40%代码，移除了所有非必要变量和冗余代码、功能函数精简、架构检测优化、安装流程简化、用户交互改进、变量命名优化、代码结构扁平化"
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
TITLE='\033[0;34m'      # 标题颜色
OPTION_NUM='\033[0;35m' # 选项编号颜色
OPTION_TEXT='\033[1;37m' # 选项文案颜色
SEPARATOR='\033[0;34m'  # 分割线颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 重置颜色

# 工具箱安装路径
TOOL_PATH="/usr/local/bin/gotool"

# 服务端配置
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BIN="server"
SERVER_SVC="gostc-admin"
SERVER_CFG="${SERVER_DIR}/config.yml"

# 节点/客户端配置
NODE_DIR="/usr/local/bin"
NODE_BIN="gostc"
NODE_SVC="gostc"

# 安装模式检测
if [ ! -t 0 ]; then
    echo -e "${TITLE}▶ 正在安装 GOSTC 工具箱...${NC}"
    sudo curl -fL "https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" || {
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
    local svc=$1 bin=$2
    
    ! command -v "$bin" &>/dev/null && echo -e "${YELLOW}[未安装]${NC}" && return
    
    if sudo systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GREEN}[运行中]${NC}"
    elif sudo systemctl is-failed --quiet "$svc" 2>/dev/null; then
        echo -e "${RED}[失败]${NC}"
    else
        echo -e "${YELLOW}[未运行]${NC}"
    fi
}

# 服务端状态
server_status() { get_service_status "$SERVER_SVC" "${SERVER_DIR}/${SERVER_BIN}"; }

# 节点状态
node_status() { get_service_status "$NODE_SVC" "${NODE_DIR}/${NODE_BIN}"; }

# 卸载工具箱
uninstall_toolbox() {
    echo -e "${YELLOW}▶ 确定要卸载 GOSTC 工具箱吗？${NC}"
    read -rp "确认卸载？(y/n, 默认n): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && sudo rm -f "$TOOL_PATH" && \
        echo -e "${GREEN}✓ GOSTC 工具箱已卸载${NC}" && exit 0
    echo -e "${TITLE}▶ 卸载已取消${NC}"
}

# 获取最新版本信息
get_latest_version() {
    local script=$(curl -s "https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh")
    local version=$(awk -F'"' '/TOOL_VERSION=/{print $2; exit}' <<< "$script")
    local changelog=$(grep -m1 '^"' <<< "$script" | cut -d'"' -f2)
    echo "$version|$changelog"
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 正在检查更新...${NC}"
    local latest_info=$(get_latest_version)
    [[ -z "$latest_info" ]] && echo -e "${RED}✗ 无法获取最新版本信息${NC}" && return
    
    IFS='|' read -r latest_version latest_changelog <<< "$latest_info"
    [[ "$latest_version" == "$TOOL_VERSION" ]] && \
        echo -e "${GREEN}✓ 当前已是最新版本 (v$TOOL_VERSION)${NC}" && return
    
    echo -e "${TITLE}▷ 当前版本: ${OPTION_TEXT}v$TOOL_VERSION${NC}"
    echo -e "${TITLE}▷ 最新版本: ${OPTION_TEXT}v$latest_version${NC}"
    echo -e "${YELLOW}════════════════ 更新日志 ════════════════${NC}"
    [[ -n "$latest_changelog" ]] && echo -e "${OPTION_TEXT}$latest_changelog${NC}" || echo -e "${YELLOW}暂无更新日志${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    
    read -rp "是否立即更新? (y/n, 默认 y): " confirm
    [[ "$confirm" == "n" ]] && echo -e "${TITLE}▶ 更新已取消${NC}" && return
    
    echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
    sudo curl -fL "https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已更新到 v$latest_version${NC}"
        echo -e "${TITLE}请重新运行 ${OPTION_TEXT}gotool${TITLE} 命令${NC}"
        exit 0
    }
    echo -e "${RED}✗ 更新失败${NC}"
}

# 自动检查更新
auto_check_update() {
    echo -e "${YELLOW}▶ 正在检查工具箱更新...${NC}"
    echo -e "${TITLE}▷ 当前版本: ${OPTION_TEXT}v$TOOL_VERSION${NC}"
    
    local latest_info=$(get_latest_version)
    [[ -z "$latest_info" ]] && echo -e "${RED}✗ 无法获取最新版本信息${NC}" && return
    
    IFS='|' read -r latest_version latest_changelog <<< "$latest_info"
    [[ "$latest_version" == "$TOOL_VERSION" ]] && \
        echo -e "${GREEN}✓ 当前已是最新版本${NC}" && return
    
    echo -e "${GREEN}✓ 发现新版本: ${OPTION_TEXT}v$latest_version${NC}"
    echo -e "${YELLOW}════════════════ 更新日志 ════════════════${NC}"
    [[ -n "$latest_changelog" ]] && echo -e "${OPTION_TEXT}$latest_changelog${NC}" || echo -e "${YELLOW}暂无更新日志${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}▶ 正在自动更新...${NC}"
    
    sudo curl -fL "https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${GREEN}✓ 工具箱已更新到 v$latest_version${NC}"
        echo -e "${TITLE}请重新运行 ${OPTION_TEXT}gotool${TITLE} 命令${NC}"
        exit 0
    }
    echo -e "${RED}✗ 自动更新失败，请手动更新${NC}"
}

# 服务管理
service_action() {
    local svc=$1 bin=$2 action=$3
    ! command -v "$bin" &>/dev/null && echo -e "${RED}✗ 未安装，请先安装${NC}" && return
    
    case $action in
        start)
            echo -e "${YELLOW}▶ 正在启动...${NC}"
            sudo systemctl start "$svc"
            sleep 2
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${GREEN}✓ 已成功启动${NC}" || \
                echo -e "${YELLOW}⚠ 启动可能存在问题${NC}"
            ;;
        restart)
            echo -e "${YELLOW}▶ 正在重启...${NC}"
            sudo systemctl restart "$svc"
            sleep 2
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${GREEN}✓ 已成功重启${NC}" || \
                echo -e "${YELLOW}⚠ 重启可能存在问题${NC}"
            ;;
        stop)
            echo -e "${YELLOW}▶ 正在停止...${NC}"
            sudo systemctl stop "$svc"
            sleep 1
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${YELLOW}⚠ 停止失败${NC}" || \
                echo -e "${GREEN}✓ 已停止${NC}"
            ;;
        uninstall)
            echo -e "${YELLOW}▶ 确定要卸载吗？${NC}"
            read -rp "确认卸载？(y/n, 默认n): " confirm
            [[ "$confirm" != "y" ]] && echo -e "${TITLE}▶ 卸载已取消${NC}" && return
            
            sudo systemctl is-active --quiet "$svc" && {
                echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
                sudo systemctl stop "$svc"
            }
            
            sudo systemctl list-unit-files | grep -q "$svc" && {
                echo -e "${YELLOW}▷ 卸载系统服务...${NC}"
                sudo "$bin" service uninstall
            }
            
            echo -e "${YELLOW}▷ 删除安装文件...${NC}"
            [[ "$svc" == "$SERVER_SVC" ]] && \
                sudo rm -rf "$SERVER_DIR" || \
                sudo rm -f "${NODE_DIR}/${NODE_BIN}"
            
            echo -e "${GREEN}✓ 已卸载${NC}"
            ;;
    esac
}

# 服务管理菜单
service_menu() {
    local svc=$1 bin=$2 dir=$3 title=$4 status_func=$5 install_func=$6
    
    while :; do
        stat=$($status_func)
        
        echo ""
        echo -e "${TITLE}${title} ${stat}${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        [[ "$svc" == "$SERVER_SVC" ]] && 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装/更新${NC}" || 
            echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}启动${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}重启${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}停止${NC}"
        echo -e "${OPTION_NUM}5. ${OPTION_TEXT}卸载${NC}"
        [[ "$svc" == "$NODE_SVC" ]] && echo -e "${OPTION_NUM}6. ${OPTION_TEXT}更新${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回主菜单${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        
        read -rp "请输入选项: " choice
        case $choice in
            1) $install_func ;;
            2) service_action "$svc" "$dir/$bin" start ;;
            3) service_action "$svc" "$dir/$bin" restart ;;
            4) service_action "$svc" "$dir/$bin" stop ;;
            5) service_action "$svc" "$dir/$bin" uninstall ;;
            6) [[ "$svc" == "$NODE_SVC" ]] && update_node || echo -e "${RED}无效选项${NC}" ;;
            0) return ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
    done
}

# 安装服务端
install_server() {
    local update_mode=false base_url="https://alist.sian.one/direct/gostc/gostc-open" version="普通版本"
    
    # 检查是否已安装
    [ -f "${SERVER_DIR}/${SERVER_BIN}" ] && {
        echo -e "${TITLE}检测到已安装服务端，请选择操作:${NC}"
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}更新到最新版本 (保留配置)${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}重新安装最新版本 (删除所有文件重新安装)${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}退出${NC}"

        read -rp "请输入选项编号 (1-3, 默认 1): " choice
        case $choice in
            2) sudo rm -rf "${SERVER_DIR}" ;;
            3) echo -e "${TITLE}操作已取消${NC}" && return ;;
            *) update_mode=true ;;
        esac
    }

    # 选择版本
    echo -e "${TITLE}请选择安装版本:${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}普通版本 (默认)${NC}"
    echo -e "${OPTION_Num}2. ${OPTION_TEXT}商业版本 (需要授权)${NC}"

    read -rp "请输入选项编号 (1-2, 默认 1): " choice
    [[ "$choice" == 2 ]] && {
        base_url="https://alist.sian.one/direct/gostc"
        version="商业版本"
        echo -e "${YELLOW}▶ 您选择了商业版本，请确保您已获得商业授权${NC}"
    }

    echo ""
    echo -e "${TITLE}▶ 开始安装 服务端 (${version})${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"

    # 架构检测
    case "$ARCH" in
        "x86_64")
            suffix="amd64_v1"
            [[ "$OS" == "linux" ]] && {
                grep -q "avx512" /proc/cpuinfo 2>/dev/null && suffix="amd64_v3"
                grep -q "avx2" /proc/cpuinfo 2>/dev/null && suffix="amd64_v1"
            }
            ;;
        "i"*"86")          suffix="386_sse2" ;;
        "aarch64"|"arm64") suffix="arm64_v8.0" ;;
        "armv7l")          suffix="arm_7" ;;
        "armv6l")          suffix="arm_6" ;;
        "armv5l")          suffix="arm_5" ;;
        "mips64")
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mips64le_hardfloat" || suffix="mips64_hardfloat"
            ;;
        "mips")
            float="softfloat"
            lscpu 2>/dev/null | grep -qi "FPU" && float="hardfloat"
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mipsle_$float" || suffix="mips_$float"
            ;;
        "riscv64")         suffix="riscv64_rva20u64" ;;
        "s390x")           suffix="s390x" ;;
        *) echo -e "${RED}错误: 不支持的架构: $ARCH${NC}" && return ;;
    esac

    # 构建下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${SERVER_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="${base_url}/${file}"

    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 创建目录并下载文件
    sudo mkdir -p "$SERVER_DIR" >/dev/null 2>&1
    curl -# -fL -o "$file" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }

    # 停止运行中的服务
    sudo systemctl is-active --quiet "$SERVER_SVC" 2>/dev/null && {
        echo -e "${YELLOW}▷ 停止运行中的服务...${NC}"
        sudo systemctl stop "$SERVER_SVC"
    }

    # 解压文件
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${SERVER_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 更新模式：保留配置文件
    $update_mode && {
        echo -e "${YELLOW}▷ 更新模式: 保留配置文件${NC}"
        sudo cp -f "$SERVER_CFG" "${SERVER_CFG}.bak" 2>/dev/null
        sudo find "${SERVER_DIR}" -maxdepth 1 -type f ! -name '*.yml' -delete
        sudo mv -f "${SERVER_CFG}.bak" "$SERVER_CFG" 2>/dev/null
    } || sudo rm -f "$SERVER_DIR/$SERVER_BIN"

    [[ "$file" == *.zip ]] && \
        sudo unzip -qo "$file" -d "$SERVER_DIR" || \
        sudo tar xzf "$file" -C "$SERVER_DIR"

    # 设置权限
    [ -f "$SERVER_DIR/$SERVER_BIN" ] && {
        sudo chmod 755 "$SERVER_DIR/$SERVER_BIN"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${SERVER_DIR}/${SERVER_BIN}${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $SERVER_BIN${NC}"
        return
    }

    # 初始化服务
    echo ""
    echo -e "${TITLE}▶ 正在初始化服务...${NC}"
    sudo systemctl list-units --full -all | grep -Fq "${SERVER_SVC}.service" || {
        echo -e "${YELLOW}▷ 安装系统服务...${NC}"
        sudo "$SERVER_DIR/$SERVER_BIN" service install
    }

    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SVC" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SVC"

    # 清理
    rm -f "$file"

    # 检查服务状态
    sleep 2
    status=$(systemctl is-active "$SERVER_SVC")
    [[ "$status" == "active" ]] && \
        echo -e "${GREEN}✓ 服务已成功启动${NC}" || \
        echo -e "${YELLOW}⚠ 服务启动可能存在问题，当前状态: ${status}${NC}"

    # 安装完成提示
    echo ""
    echo -e "${TITLE}版本: ${OPTION_TEXT}${version}${NC}"
    echo -e "${TITLE}安装目录: ${OPTION_TEXT}$SERVER_DIR${NC}"
    echo -e "${TITLE}服务状态: $([ "$status" = "active" ] && echo -e "${GREEN}运行中${NC}" || echo -e "${YELLOW}未运行${NC}")"
    echo -e "${TITLE}访问地址: ${OPTION_TEXT}http://localhost:8080${NC}"

    # 显示初始凭据
    [ ! -f "$SERVER_CFG" ] && ! $update_mode && {
        echo ""
        echo -e "${YELLOW}════════════════ 重要提示 ══════════════════${NC}"
        echo -e "${YELLOW}首次安装，请使用以下默认凭据登录:${NC}"
        echo -e "用户名: ${OPTION_TEXT}admin${NC}"
        echo -e "密码: ${OPTION_TEXT}admin${NC}"
        echo -e "${YELLOW}登录后请立即修改密码${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    }
}

# 安装节点/客户端
install_node() {
    # 选择类型
    echo ""
    echo -e "${TITLE}▶ 请选择安装类型${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${OPTION_NUM}1. ${OPTION_TEXT}安装节点 (默认)${NC}"
    echo -e "${OPTION_NUM}2. ${OPTION_TEXT}安装客户端${NC}"
    echo -e "${OPTION_NUM}0. ${OPTION_TEXT}返回${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    read -p "$(echo -e "${TITLE}▷ 请输入选择 [1-2] (默认1): ${NC}")" choice
    choice=${choice:-1}
    [[ "$choice" == 0 ]] && return
    
    local type="节点"
    [[ "$choice" == 2 ]] && type="客户端"
    
    echo ""
    echo -e "${TITLE}▶ 开始安装 ${OPTION_TEXT}${type}${TITLE} 组件${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"
    
    # 架构检测
    case "$ARCH" in
        "x86_64") suffix="amd64_v1" ;;
        "i"*"86") suffix="386_sse2" ;;
        "aarch64"|"arm64") suffix="arm64_v8.0" ;;
        "armv7l") suffix="arm_7" ;;
        "armv6l") suffix="arm_6" ;;
        "armv5l") suffix="arm_5" ;;
        "mips64")
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mips64le_hardfloat" || suffix="mips64_hardfloat"
            ;;
        "mips")
            float="softfloat"
            lscpu 2>/dev/null | grep -qi "FPU" && float="hardfloat"
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mipsle_$float" || suffix="mips_$float"
            ;;
        "riscv64") suffix="riscv64_rva20u64" ;;
        "s390x") suffix="s390x" ;;
        *) echo -e "${RED}错误: 不支持的架构: $ARCH${NC}" && return ;;
    esac
    
    # 构建下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${NODE_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="https://alist.sian.one/direct/gostc/${file}"
    
    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    # 下载文件
    sudo mkdir -p "$NODE_DIR" >/dev/null 2>&1
    curl -# -fL -o "$file" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }
    
    # 解压文件
    echo ""
    echo -e "${TITLE}▶ 正在安装到: ${OPTION_TEXT}${NODE_DIR}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    
    sudo rm -f "$NODE_DIR/$NODE_BIN"
    [[ "$file" == *.zip ]] && \
        sudo unzip -qo "$file" -d "$NODE_DIR" || \
        sudo tar xzf "$file" -C "$NODE_DIR"
    
    # 设置权限
    [ -f "$NODE_DIR/$NODE_BIN" ] && {
        sudo chmod 755 "$NODE_DIR/$NODE_BIN"
        echo -e "${GREEN}✓ 已安装二进制文件: ${OPTION_TEXT}${NODE_DIR}/${NODE_BIN}${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BIN${NC}"
        return
    }
    
    # 清理
    rm -f "$file"
    
    # 配置
    [[ "$type" == "节点" ]] && configure_node || configure_client
}

# 验证服务器地址
validate_server() {
    local addr=$1 tls=$2
    [[ "$tls" == "true" ]] && prefix="https://" || prefix="http://"
    [[ "$addr" != http* ]] && addr="${prefix}${addr}"
    
    echo -e "${TITLE}▷ 验证服务器地址: ${OPTION_TEXT}$addr${NC}"
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$addr")
    
    if [ "$status" -eq 200 ]; then
        echo -e "${GREEN}✓ 服务器验证成功 (HTTP $status)${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务器验证失败 (HTTP $status)${NC}"
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
    local tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] && tls="true"
    
    # 服务器地址
    local addr="127.0.0.1:8080"
    while :; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input
        input=${input:-$addr}
        validate_server "$input" "$tls" && addr="$input" && break
        echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
    done
    
    # 节点密钥
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入节点密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ 节点密钥不能为空${NC}"
    done
    
    # 网关代理选项
    local proxy=""
    read -p "$(echo -e "${TITLE}▷ 是否使用网关代理? (y/n, 默认n): ${NC}")" choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        while :; do
            read -p "$(echo -e "${TITLE}▷ 输入网关地址 (包含http/https前缀): ${NC}")" url
            [[ "$url" =~ ^https?:// ]] && proxy="$url" && break
            echo -e "${RED}✗ 网关地址必须以http://或https://开头${NC}"
        done
    fi
    
    # 构建安装命令
    local cmd="sudo $NODE_DIR/$NODE_BIN install --tls=$tls -addr $addr -s -key $key"
    [ -n "$proxy" ] && cmd+=" --proxy-base-url $proxy"
    
    # 执行安装
    echo ""
    echo -e "${TITLE}▶ 正在配置节点${NC}"
    eval "$cmd" || {
        echo -e "${RED}✗ 节点配置失败${NC}"
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SVC" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}节点${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$tls${NC}"
    [ -n "$proxy" ] && echo -e "${TITLE}网关地址: ${OPTION_TEXT}$proxy${NC}"
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
    local tls="false"
    read -p "$(echo -e "${TITLE}▷ 是否使用TLS? (y/n, 默认n): ${NC}")" choice
    [[ "$choice" =~ ^[Yy]$ ]] && tls="true"
    
    # 服务器地址
    local addr="127.0.0.1:8080"
    while :; do
        read -p "$(echo -e "${TITLE}▷ 输入服务器地址 (默认 ${OPTION_TEXT}127.0.0.1:8080${TITLE}): ${NC}")" input
        input=${input:-$addr}
        validate_server "$input" "$tls" && addr="$input" && break
        echo -e "${RED}✗ 请重新输入有效的服务器地址${NC}"
    done
    
    # 客户端密钥
    local key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${TITLE}▷ 输入客户端密钥: ${NC}")" key
        [ -z "$key" ] && echo -e "${RED}✗ 客户端密钥不能为空${NC}"
    done
    
    # 构建安装命令
    local cmd="sudo $NODE_DIR/$NODE_BIN install --tls=$tls -addr $addr -key $key"
    
    # 执行安装
    echo ""
    echo -e "${TITLE}▶ 正在配置客户端${NC}"
    eval "$cmd" || {
        echo -e "${RED}✗ 客户端配置失败${NC}"
        return
    }
    
    # 启动服务
    echo ""
    echo -e "${TITLE}▶ 正在启动服务${NC}"
    sudo systemctl start "$NODE_SVC" || {
        echo -e "${RED}✗ 服务启动失败${NC}"
        return
    }
    
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 安装完成提示
    echo ""
    echo -e "${TITLE}组件: ${OPTION_TEXT}客户端${NC}"
    echo -e "${TITLE}服务器地址: ${OPTION_TEXT}$addr${NC}"
    echo -e "${TITLE}TLS: ${OPTION_TEXT}$tls${NC}"
}

# 更新节点
update_node() {
    ! command -v "$NODE_BIN" &>/dev/null && \
        echo -e "${RED}✗ 节点/客户端未安装，请先安装${NC}" && return

    # 获取系统信息
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    echo -e "${TITLE}▷ 检测系统: ${OPTION_TEXT}${OS} ${ARCH}${NC}"

    # 架构检测
    case "$ARCH" in
        "x86_64") suffix="amd64_v1" ;;
        "i"*"86") suffix="386_sse2" ;;
        "aarch64"|"arm64") suffix="arm64_v8.0" ;;
        "armv7l") suffix="arm_7" ;;
        "armv6l") suffix="arm_6" ;;
        "armv5l") suffix="arm_5" ;;
        "mips64") 
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mips64le_hardfloat" || suffix="mips64_hardfloat"
            ;;
        "mips")
            float="softfloat"
            lscpu 2>/dev/null | grep -qi "FPU" && float="hardfloat"
            lscpu 2>/dev/null | grep -qi "little endian" && suffix="mipsle_$float" || suffix="mips_$float"
            ;;
        "riscv64") suffix="riscv64_rva20u64" ;;
        "s390x") suffix="s390x" ;;
        *) echo -e "${RED}错误: 不支持的架构: $ARCH${NC}" && return ;;
    esac

    # 构建下载URL
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    file="${NODE_BIN}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="https://alist.sian.one/direct/gostc/${file}"

    echo -e "${TITLE}▷ 下载文件: ${OPTION_TEXT}${file}${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"

    # 创建临时目录
    tmp=$(mktemp -d)
    cd "$tmp" || return

    # 下载文件
    curl -# -fL -o "$file" "$url" || {
        echo -e "${RED}✗ 错误: 文件下载失败!${NC}"
        return
    }

    # 停止服务
    echo -e "${YELLOW}▷ 停止节点/客户端服务...${NC}"
    sudo systemctl stop "$NODE_SVC"

    # 解压文件
    [[ "$file" == *.zip ]] && \
        unzip -qo "$file" -d "$tmp" || \
        tar xzf "$file" -C "$tmp"

    # 更新文件
    [ -f "$tmp/$NODE_BIN" ] && {
        sudo mv -f "$tmp/$NODE_BIN" "${NODE_DIR}/${NODE_BIN}"
        sudo chmod 755 "${NODE_DIR}/${NODE_BIN}"
        echo -e "${GREEN}✓ 节点/客户端更新成功${NC}"
    } || {
        echo -e "${RED}错误: 解压后未找到二进制文件 $NODE_BIN${NC}"
        sudo systemctl start "$NODE_SVC"
        return
    }

    # 清理
    cd - >/dev/null || return
    rm -rf "$tmp"

    # 启动服务
    echo -e "${YELLOW}▷ 启动节点/客户端服务...${NC}"
    sudo systemctl start "$NODE_SVC"

    # 检查状态
    sleep 2
    sudo systemctl is-active --quiet "$NODE_SVC" && \
        echo -e "${GREEN}✓ 节点/客户端已成功启动${NC}" || \
        echo -e "${YELLOW}⚠ 节点/客户端启动可能存在问题${NC}"
}

# 显示工具箱信息
show_info() {
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${TITLE}          GOSTC 服务管理工具箱 v${TOOL_VERSION}           ${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
    echo -e "${TITLE}▷ 服务端状态: $(server_status)${NC}"
    echo -e "${TITLE}▷ 节点/客户端状态: $(node_status)${NC}"
    echo -e "${SEPARATOR}==================================================${NC}"
}

# 主菜单
main_menu() {
    auto_check_update
    
    while :; do
        show_info
        
        echo -e "${OPTION_NUM}1. ${OPTION_TEXT}服务端管理${NC}"
        echo -e "${OPTION_NUM}2. ${OPTION_TEXT}节点/客户端管理${NC}"
        echo -e "${OPTION_NUM}3. ${OPTION_TEXT}检查更新${NC}"
        echo -e "${OPTION_NUM}4. ${OPTION_TEXT}卸载工具箱${NC}"
        echo -e "${OPTION_NUM}0. ${OPTION_TEXT}退出${NC}"
        echo -e "${SEPARATOR}==================================================${NC}"
        
        read -rp "请输入选项: " choice
        case $choice in
            1) service_menu "$SERVER_SVC" "$SERVER_BIN" "$SERVER_DIR" "GOSTC 服务端管理" server_status install_server ;;
            2) service_menu "$NODE_SVC" "$NODE_BIN" "$NODE_DIR" "GOSTC 节点/客户端管理" node_status install_node ;;
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
