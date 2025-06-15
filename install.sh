#!/bin/bash

# ==============================================
# GOSTC 全能服务管理工具箱 v2.1
# 修复更新：2023-12-15
# 远程更新：https://gh-proxy.com/raw.githubusercontent.com/dxiaom/gotool/main/install.sh
# ==============================================

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
SCRIPT_VERSION="2.1.0"
SCRIPT_NAME="gotool"
INSTALL_PATH="/usr/local/bin/$SCRIPT_NAME"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/dxiaom/gotool/main/install.sh"
TOOLBOX_BANNER="${PURPLE}
╔══════════════════════════════════════════════════╗
║               ${WHITE}GOSTC 服务管理工具箱 ${PURPLE}v${SCRIPT_VERSION}          ║
╠══════════════════════════════════════════════════╣
║  高效管理 • 一键部署 • 智能运维 • 全平台支持     ║
╚══════════════════════════════════════════════════╝
${NC}"

# 安装自身到系统
install_self() {
    # 检查是否已安装
    if [[ -f "$INSTALL_PATH" ]]; then
        echo -e "${GREEN}✓ 工具箱已安装，请使用命令: ${WHITE}gotool${NC}"
        return
    fi
    
    echo -e "${YELLOW}▶ 正在安装工具箱到系统...${NC}"
    echo -e "${CYAN}下载地址: ${WHITE}$REMOTE_SCRIPT_URL${NC}"
    
    if ! sudo curl -# -fL "$REMOTE_SCRIPT_URL" -o "$INSTALL_PATH"; then
        echo -e "${RED}✗ 工具箱安装失败! 请检查网络连接${NC}"
        return 1
    fi
    
    sudo chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}✓ 工具箱已安装到: ${WHITE}$INSTALL_PATH${NC}"
    echo -e "${YELLOW}════════════════ 使用说明 ══════════════════${NC}"
    echo -e "${GREEN}请使用命令 ${WHITE}$SCRIPT_NAME${GREEN} 运行工具箱${NC}"
    echo -e "${GREEN}快捷命令: ${WHITE}gotool${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
}

# 检查更新
check_update() {
    echo -e "${YELLOW}▶ 检查工具箱更新...${NC}"
    
    # 获取远程版本
    remote_version=$(curl -sSf "$REMOTE_SCRIPT_URL" | grep -m1 "SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo -e "${YELLOW}⚠ 无法获取远程版本信息${NC}"
        return
    fi
    
    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "${YELLOW}发现新版本: $remote_version (当前: $SCRIPT_VERSION)${NC}"
        read -p "$(echo -e "${BLUE}是否更新到最新版本? (y/n, 默认y): ${NC}")" update_choice
        
        if [[ ! "$update_choice" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}▶ 正在更新工具箱...${NC}"
            
            if ! sudo curl -# -fL "$REMOTE_SCRIPT_URL" -o "$0"; then
                echo -e "${RED}✗ 更新失败! 请重试或手动下载${NC}"
                return
            fi
            
            chmod +x "$0"
            echo -e "${GREEN}✓ 已成功更新到 v$remote_version${NC}"
            echo -e "${YELLOW}请重新运行脚本生效${NC}"
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
    
    # 添加协议前缀
    if [[ "$use_tls" == "true" ]]; then
        [[ "$address" != https://* ]] && address="https://$address"
    else
        [[ "$address" != http://* ]] && address="http://$address"
    fi
    
    echo -e "${BLUE}▷ 验证服务器: ${WHITE}$address${NC}"
    
    # 设置超时快速验证
    local status_code
    if ! status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$address"); then
        echo -e "${YELLOW}⚠ 服务器连接超时，请手动验证${NC}"
        return 0
    fi
    
    if [[ "$status_code" =~ ^(200|401|403)$ ]]; then
        echo -e "${GREEN}✓ 服务器响应正常 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 服务器响应异常 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 获取系统架构
get_architecture() {
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)
    local FILE_SUFFIX=""
    
    # 特殊系统处理
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    
    # 架构检测优化
    case "$ARCH" in
        "x86_64")
            FILE_SUFFIX="amd64_v1"
            if [[ "$OS" == "linux" ]]; then
                grep -q "avx512" /proc/cpuinfo 2>/dev/null && FILE_SUFFIX="amd64_v3"
                grep -q "avx2" /proc/cpuinfo 2>/dev/null && FILE_SUFFIX="amd64_v1"
            fi
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
            local FLOAT="softfloat"
            lscpu 2>/dev/null | grep -qi "FPU" && FLOAT="hardfloat"
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
    
    echo "${OS}_${FILE_SUFFIX}"
}

# 下载并安装组件
download_component() {
    local component=$1
    local version=$2
    local target_dir=$3
    
    # 获取系统架构
    local arch_info
    if ! arch_info=$(get_architecture); then
        return 1
    fi
    
    # 构建下载URL
    local base_url="https://alist.sian.one/direct/gostc"
    [[ "$version" == "commercial" ]] && base_url="https://alist.sian.one/direct/gostc-pro"
    
    local file_name="${component}_${arch_info}"
    [[ "$arch_info" == windows* ]] && file_name="${file_name}.zip" || file_name="${file_name}.tar.gz"
    
    local download_url="${base_url}/${file_name}"
    
    # 显示下载信息
    echo -e "${BLUE}▷ 下载组件: ${WHITE}$component${NC}"
    echo -e "${BLUE}▷ 文件名称: ${WHITE}$file_name${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    
    # 创建目标目录
    sudo mkdir -p "$target_dir" >/dev/null 2>&1
    
    # 下载文件
    if ! curl -# -fL -o "$file_name" "$download_url"; then
        echo -e "${RED}✗ 下载失败! 可能原因:${NC}"
        echo -e "1. 网络连接问题"
        echo -e "2. 平台暂不支持 ($arch_info)"
        echo -e "3. 资源路径错误"
        echo -e "${YELLOW}URL: $download_url${NC}"
        return 1
    fi
    
    # 解压文件
    echo -e "${BLUE}▶ 正在安装到: ${WHITE}$target_dir${NC}"
    
    if [[ "$file_name" == *.zip ]]; then
        if ! sudo unzip -qo "$file_name" -d "$target_dir"; then
            echo -e "${RED}✗ 解压失败! 文件可能损坏${NC}"
            return 1
        fi
    else
        if ! sudo tar xzf "$file_name" -C "$target_dir"; then
            echo -e "${RED}✗ 解压失败! 文件可能损坏${NC}"
            return 1
        fi
    fi
    
    # 设置权限
    local binary_name="$component"
    [[ "$component" == "server" ]] && binary_name="server"
    
    if [[ -f "$target_dir/$binary_name" ]]; then
        sudo chmod 755 "$target_dir/$binary_name"
        echo -e "${GREEN}✓ 安装成功: ${WHITE}$target_dir/$binary_name${NC}"
    else
        echo -e "${RED}✗ 文件未找到: $binary_name${NC}"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$file_name"
    return 0
}

# 服务端安装
install_server() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 服务端安装向导${PURPLE}              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 配置参数
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    local CONFIG_FILE="${TARGET_DIR}/config.yml"

    # 检测现有安装
    local operation="install"
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${YELLOW}检测到已安装的服务端${NC}"
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "1. 更新到最新版本 (保留配置)"
        echo -e "2. 重新安装 (清除所有数据)"
        echo -e "3. 返回主菜单"
        
        read -rp "请输入选项 (1-3): " choice
        case "$choice" in
            2)
                echo -e "${YELLOW}▶ 开始全新安装...${NC}"
                sudo rm -rf "${TARGET_DIR}"
                ;;
            3)
                return
                ;;
            *)
                echo -e "${YELLOW}▶ 开始更新...${NC}"
                operation="update"
                ;;
        esac
    fi

    # 版本选择
    echo -e "${BLUE}请选择版本:${NC}"
    echo -e "1. 普通版 (默认)"
    echo -e "2. 商业版 (需要授权)"
    
    read -rp "请输入选项 (1-2): " version_choice
    local version_type="standard"
    [[ "$version_choice" == "2" ]] && version_type="commercial"

    # 开始安装
    if ! download_component "server" "$version_type" "$TARGET_DIR"; then
        echo -e "${RED}✗ 服务端安装失败${NC}"
        return
    fi

    # 服务管理
    echo -e "${CYAN}════════════════ 服务配置 ═════════════════${NC}"
    
    # 安装系统服务
    if ! sudo systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}.service"; then
        echo -e "${YELLOW}▷ 注册系统服务...${NC}"
        sudo "${TARGET_DIR}/${BINARY_NAME}" service install || {
            echo -e "${RED}✗ 服务注册失败${NC}"
            return
        }
    fi

    # 启动服务
    echo -e "${YELLOW}▷ 启动服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    
    if ! sudo systemctl restart "$SERVICE_NAME"; then
        echo -e "${YELLOW}⚠ 服务启动异常，请查看日志: journalctl -u $SERVICE_NAME${NC}"
    fi

    # 等待服务状态
    sleep 2
    local SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
    
    # 安装结果
    echo -e "${CYAN}════════════════ 安装完成 ═════════════════${NC}"
    echo -e "${GREEN}✓ 服务端${operation}完成!${NC}"
    echo -e "版本: ${YELLOW}${version_type}版${NC}"
    echo -e "目录: ${WHITE}${TARGET_DIR}${NC}"
    echo -e "状态: $( [[ "$SERVICE_STATUS" == "active" ]] && echo -e "${GREEN}运行中${NC}" || echo -e "${YELLOW}未运行${NC}" )"
    echo -e "管理: ${WHITE}systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
    
    # 初始凭据提示
    if [[ "$operation" == "install" && ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}════════════════ 登录信息 ═════════════════${NC}"
        echo -e "用户名: ${WHITE}admin${NC}"
        echo -e "密  码: ${WHITE}admin${NC}"
        echo -e "${YELLOW}请及时登录修改密码${NC}"
    fi
    
    read -rp "$(echo -e "${BLUE}按回车键返回...${NC}")"
}

# 服务端管理
manage_server() {
    local TARGET_DIR="/usr/local/gostc-admin"
    local BINARY_NAME="server"
    local SERVICE_NAME="gostc-admin"
    
    while true; do
        # 获取服务状态
        local status_text="${RED}未安装${NC}"
        if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                status_text="${GREEN}运行中${NC}"
            else
                status_text="${YELLOW}已停止${NC}"
            fi
        fi
        
        clear
        echo -e "${PURPLE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║              ${WHITE}GOSTC 服务端管理${PURPLE}               ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  状态: $status_text                            ║"
        echo -e "║  路径: ${WHITE}$TARGET_DIR${PURPLE}               ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${PURPLE} ${WHITE}安装/更新服务端${PURPLE}                        ║"
        echo -e "║  ${CYAN}2.${PURPLE} ${WHITE}启动服务${PURPLE}                              ║"
        echo -e "║  ${CYAN}3.${PURPLE} ${WHITE}停止服务${PURPLE}                              ║"
        echo -e "║  ${CYAN}4.${PURPLE} ${WHITE}重启服务${PURPLE}                              ║"
        echo -e "║  ${CYAN}5.${PURPLE} ${WHITE}查看状态${PURPLE}                              ║"
        echo -e "║  ${CYAN}6.${PURPLE} ${WHITE}卸载服务${PURPLE}                              ║"
        echo -e "║  ${CYAN}0.${PURPLE} ${WHITE}返回主菜单${PURPLE}                            ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-6): " choice
        
        case $choice in
            1) install_server ;;
            2)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl start "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已启动${NC}"
                sleep 1
                ;;
            3)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl stop "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已停止${NC}"
                sleep 1
                ;;
            4)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl restart "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已重启${NC}"
                sleep 1
                ;;
            5)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                else
                    echo -e "${YELLOW}▶ 服务状态信息${NC}"
                    systemctl status "$SERVICE_NAME" --no-pager -l
                fi
                read -rp "按回车键继续..."
                ;;
            6)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                
                echo -e "${RED}⚠ 警告: 此操作将完全卸载服务端!${NC}"
                read -p "确认卸载? (y/n, 默认n): " confirm
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    echo -e "${BLUE}操作已取消${NC}"
                    sleep 1
                    continue
                fi
                
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
                
                echo -e "${YELLOW}▶ 正在卸载服务...${NC}"
                sudo "${TARGET_DIR}/${BINARY_NAME}" service uninstall 2>/dev/null
                
                echo -e "${YELLOW}▶ 删除文件...${NC}"
                sudo rm -rf "$TARGET_DIR"
                
                echo -e "${GREEN}✓ 服务端已卸载${NC}"
                sleep 2
                ;;
            0) return ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 节点安装
install_node() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 节点安装向导${BLUE}               ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 配置参数
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    # 检测现有安装
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${YELLOW}检测到已安装的节点${NC}"
        read -p "是否更新? (y/n, 默认y): " update_choice
        if [[ "$update_choice" == "n" || "$update_choice" == "N" ]]; then
            return
        fi
    fi

    # 开始安装
    if ! download_component "gostc" "standard" "$TARGET_DIR"; then
        echo -e "${RED}✗ 节点安装失败${NC}"
        return
    fi

    # 节点配置
    echo -e "${CYAN}════════════════ 节点配置 ═════════════════${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}使用TLS加密连接? (y/n, 默认n): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"

    # 服务器地址
    local server_addr=""
    while [[ -z "$server_addr" ]]; do
        read -p "$(echo -e "${BLUE}服务端地址 (IP:端口 或 域名): ${NC}")" server_addr
    done
    
    # 验证地址
    validate_server_address "$server_addr" "$use_tls"

    # 节点密钥
    local node_key=""
    while [[ -z "$node_key" ]]; do
        read -p "$(echo -e "${BLUE}节点密钥 (服务端获取): ${NC}")" node_key
    done

    # 网关代理
    local proxy_base_url=""
    read -p "$(echo -e "${BLUE}使用网关代理? (y/n, 默认n): ${NC}")" proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        while [[ -z "$proxy_base_url" ]]; do
            read -p "$(echo -e "${BLUE}网关地址 (http:// 或 https://): ${NC}")" proxy_base_url
            [[ "$proxy_base_url" =~ ^https?:// ]] || proxy_base_url=""
        done
    fi

    # 安装节点
    echo -e "${YELLOW}▶ 注册节点服务...${NC}"
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -s -key $node_key"
    [[ -n "$proxy_base_url" ]] && install_cmd+=" --proxy-base-url $proxy_base_url"
    
    if ! eval "$install_cmd"; then
        echo -e "${RED}✗ 节点配置失败! 请检查参数${NC}"
        return
    fi

    # 启动服务
    echo -e "${YELLOW}▶ 启动节点服务...${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 节点启动成功${NC}"
    else
        echo -e "${YELLOW}⚠ 节点启动异常，请查看日志: journalctl -u $SERVICE_NAME${NC}"
    fi

    # 安装结果
    echo -e "${CYAN}════════════════ 安装完成 ═════════════════${NC}"
    echo -e "${GREEN}✓ 节点配置完成!${NC}"
    echo -e "服务端: ${WHITE}$server_addr${NC}"
    echo -e "TLS: ${WHITE}$use_tls${NC}"
    [[ -n "$proxy_base_url" ]] && echo -e "网关: ${WHITE}$proxy_base_url${NC}"
    echo -e "管理: ${WHITE}systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
    
    read -rp "$(echo -e "${BLUE}按回车键返回...${NC}")"
}

# 客户端安装
install_client() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo -e "║              ${WHITE}GOSTC 客户端安装向导${BLUE}             ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 配置参数
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    # 检测现有安装
    if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
        echo -e "${YELLOW}检测到已安装的客户端${NC}"
        read -p "是否更新? (y/n, 默认y): " update_choice
        if [[ "$update_choice" == "n" || "$update_choice" == "N" ]]; then
            return
        fi
    fi

    # 开始安装
    if ! download_component "gostc" "standard" "$TARGET_DIR"; then
        echo -e "${RED}✗ 客户端安装失败${NC}"
        return
    fi

    # 客户端配置
    echo -e "${CYAN}════════════════ 客户端配置 ═════════════════${NC}"
    
    # TLS选项
    local use_tls="false"
    read -p "$(echo -e "${BLUE}使用TLS加密连接? (y/n, 默认n): ${NC}")" tls_choice
    [[ "$tls_choice" =~ ^[Yy]$ ]] && use_tls="true"

    # 服务器地址
    local server_addr=""
    while [[ -z "$server_addr" ]]; do
        read -p "$(echo -e "${BLUE}服务端地址 (IP:端口 或 域名): ${NC}")" server_addr
    done
    
    # 验证地址
    validate_server_address "$server_addr" "$use_tls"

    # 客户端密钥
    local client_key=""
    while [[ -z "$client_key" ]]; do
        read -p "$(echo -e "${BLUE}客户端密钥 (服务端获取): ${NC}")" client_key
    done

    # 安装客户端
    echo -e "${YELLOW}▶ 注册客户端服务...${NC}"
    local install_cmd="sudo $TARGET_DIR/$BINARY_NAME install --tls=$use_tls -addr $server_addr -key $client_key"
    
    if ! eval "$install_cmd"; then
        echo -e "${RED}✗ 客户端配置失败! 请检查参数${NC}"
        return
    fi

    # 启动服务
    echo -e "${YELLOW}▶ 启动客户端服务...${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 客户端启动成功${NC}"
    else
        echo -e "${YELLOW}⚠ 客户端启动异常，请查看日志: journalctl -u $SERVICE_NAME${NC}"
    fi

    # 安装结果
    echo -e "${CYAN}════════════════ 安装完成 ═════════════════${NC}"
    echo -e "${GREEN}✓ 客户端配置完成!${NC}"
    echo -e "服务端: ${WHITE}$server_addr${NC}"
    echo -e "TLS: ${WHITE}$use_tls${NC}"
    echo -e "管理: ${WHITE}systemctl [start|stop|restart|status] ${SERVICE_NAME}${NC}"
    
    read -rp "$(echo -e "${BLUE}按回车键返回...${NC}")"
}

# 节点/客户端管理
manage_client() {
    local TARGET_DIR="/usr/local/bin"
    local BINARY_NAME="gostc"
    local SERVICE_NAME="gostc"
    
    while true; do
        # 获取服务状态
        local status_text="${RED}未安装${NC}"
        if [[ -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                status_text="${GREEN}运行中${NC}"
            else
                status_text="${YELLOW}已停止${NC}"
            fi
        fi
        
        clear
        echo -e "${BLUE}"
        echo "╔══════════════════════════════════════════════════╗"
        echo -e "║            ${WHITE}GOSTC 节点/客户端管理${BLUE}            ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  状态: $status_text                            ║"
        echo -e "║  路径: ${WHITE}$TARGET_DIR${BLUE}                      ║"
        echo "╠══════════════════════════════════════════════════╣"
        echo -e "║  ${CYAN}1.${BLUE} ${WHITE}安装节点${BLUE}                                ║"
        echo -e "║  ${CYAN}2.${BLUE} ${WHITE}安装客户端${BLUE}                              ║"
        echo -e "║  ${CYAN}3.${BLUE} ${WHITE}启动服务${BLUE}                                ║"
        echo -e "║  ${CYAN}4.${BLUE} ${WHITE}停止服务${BLUE}                                ║"
        echo -e "║  ${CYAN}5.${BLUE} ${WHITE}重启服务${BLUE}                                ║"
        echo -e "║  ${CYAN}6.${BLUE} ${WHITE}查看状态${BLUE}                                ║"
        echo -e "║  ${CYAN}7.${BLUE} ${WHITE}卸载服务${BLUE}                                ║"
        echo -e "║  ${CYAN}0.${BLUE} ${WHITE}返回主菜单${BLUE}                              ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "请选择操作 (0-7): " choice
        
        case $choice in
            1) install_node ;;
            2) install_client ;;
            3)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl start "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已启动${NC}"
                sleep 1
                ;;
            4)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl stop "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已停止${NC}"
                sleep 1
                ;;
            5)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                sudo systemctl restart "$SERVICE_NAME"
                echo -e "${GREEN}✓ 服务已重启${NC}"
                sleep 1
                ;;
            6)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                else
                    echo -e "${YELLOW}▶ 服务状态信息${NC}"
                    systemctl status "$SERVICE_NAME" --no-pager -l
                fi
                read -rp "按回车键继续..."
                ;;
            7)
                if [[ ! -f "${TARGET_DIR}/${BINARY_NAME}" ]]; then
                    echo -e "${RED}✗ 服务未安装!${NC}"
                    sleep 1
                    continue
                fi
                
                echo -e "${RED}⚠ 警告: 此操作将完全卸载服务!${NC}"
                read -p "确认卸载? (y/n, 默认n): " confirm
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    echo -e "${BLUE}操作已取消${NC}"
                    sleep 1
                    continue
                fi
                
                echo -e "${YELLOW}▶ 正在停止服务...${NC}"
                sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
                
                echo -e "${YELLOW}▶ 正在卸载服务...${NC}"
                sudo "$TARGET_DIR/$BINARY_NAME" uninstall 2>/dev/null
                
                echo -e "${YELLOW}▶ 删除文件...${NC}"
                sudo rm -f "$TARGET_DIR/$BINARY_NAME"
                
                echo -e "${GREEN}✓ 服务已卸载${NC}"
                sleep 2
                ;;
            0) return ;;
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
    if [[ ! -f "$INSTALL_PATH" ]]; then
        clear
        echo -e "$TOOLBOX_BANNER"
        echo -e "${GREEN}首次使用，需安装工具箱到系统${NC}"
        echo -e "${YELLOW}安装后可通过命令 ${WHITE}gotool${YELLOW} 快速启动${NC}"
        echo ""
        
        install_self
        return
    fi

    # 检查更新
    check_update

    while true; do
        clear
        echo -e "$TOOLBOX_BANNER"
        
        echo -e "${BLUE}请选择操作:${NC}"
        echo -e "${CYAN}1. ${WHITE}服务端管理${NC}"
        echo -e "${CYAN}2. ${WHITE}节点/客户端管理${NC}"
        echo -e "${CYAN}3. ${WHITE}更新工具箱${NC}"
        echo -e "${CYAN}0. ${WHITE}退出${NC}"
        echo -e "${CYAN}════════════════════════════════════════${NC}"
        
        read -p "请输入选项 (0-3): " choice
        
        case $choice in
            1) manage_server ;;
            2) manage_client ;;
            3) check_update ;;
            0)
                echo -e "${GREEN}感谢使用，再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动逻辑
if [[ "$0" != "$INSTALL_PATH" && "$0" != "bash" ]]; then
    # 直接运行脚本时的处理
    if [[ ! -f "$INSTALL_PATH" ]]; then
        # 首次安装
        install_self
    else
        # 已经安装则进入主菜单
        main_menu
    fi
else
    # 通过gotool命令调用
    if [[ -f "$INSTALL_PATH" ]]; then
        main_menu
    else
        echo -e "${RED}错误: 工具箱未安装!${NC}"
        echo -e "请使用以下命令安装:"
        echo -e "curl -sSL ${REMOTE_SCRIPT_URL} | bash"
        exit 1
    fi
fi
