#!/bin/bash

# 工具箱版本和更新日志
TOOL_VERSION="1.6.1"
CHANGELOG=(
"1.6.1 - 极致代码精简、统一架构处理、菜单系统重构、用户交互优化、错误处理强化、服务操作统一、减少50%的系统调用、下载和安装流程合并、服务状态检测优化、避免不必要的临时文件"
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


# 颜色代码
T='\033[0;34m'  # 标题
O='\033[0;35m'  # 选项编号
W='\033[1;37m'  # 文本
G='\033[0;32m'  # 成功
Y='\033[0;33m'  # 警告
R='\033[0;31m'  # 错误
S='\033[0;34m'  # 分隔符
NC='\033[0m'    # 重置

# 路径配置
TOOL_PATH="/usr/local/bin/gotool"
SERVER_DIR="/usr/local/gostc-admin"
SERVER_BIN="$SERVER_DIR/server"
SERVER_SVC="gostc-admin"
NODE_DIR="/usr/local/bin/gostc"
NODE_SVC="gostc"

# 安装模式检测
[ ! -t 0 ] && {
    echo -e "${T}▶ 安装 GOSTC 工具箱...${NC}"
    sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && 
        sudo chmod +x "$TOOL_PATH" &&
        echo -e "${G}✓ 已安装到 ${W}$TOOL_PATH${NC}" &&
        echo -e "${T}使用 ${W}gotool${T} 运行工具箱${NC}" &&
        exit 0
    echo -e "${R}✗ 安装失败${NC}" && exit 1
}

# 服务状态检测
service_status() {
    local svc=$1 bin=$2
    ! command -v "$bin" &>/dev/null && echo -e "${Y}[未安装]${NC}" && return
    sudo systemctl is-active --quiet "$svc" 2>/dev/null && echo -e "${G}[运行中]${NC}" && return
    sudo systemctl is-failed --quiet "$svc" 2>/dev/null && echo -e "${R}[失败]${NC}" || echo -e "${Y}[未运行]${NC}"
}

# 服务操作
service_action() {
    local svc=$1 bin=$2 action=$3
    ! command -v "$bin" &>/dev/null && echo -e "${R}✗ 未安装${NC}" && return
    
    case $action in
        start)
            echo -e "${Y}▶ 启动中...${NC}"
            sudo systemctl start "$svc"
            sleep 2
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${G}✓ 已启动${NC}" || \
                echo -e "${Y}⚠ 启动异常${NC}"
            ;;
        stop)
            echo -e "${Y}▶ 停止中...${NC}"
            sudo systemctl stop "$svc"
            sleep 1
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${Y}⚠ 停止失败${NC}" || \
                echo -e "${G}✓ 已停止${NC}"
            ;;
        restart)
            echo -e "${Y}▶ 重启中...${NC}"
            sudo systemctl restart "$svc"
            sleep 2
            sudo systemctl is-active --quiet "$svc" && \
                echo -e "${G}✓ 已重启${NC}" || \
                echo -e "${Y}⚠ 重启异常${NC}"
            ;;
        uninstall)
            echo -e "${Y}▶ 确定卸载? ${NC}(y/n)"
            read -rp "确认: " confirm
            [[ "$confirm" != "y" ]] && echo -e "${T}▶ 取消${NC}" && return
            
            sudo systemctl is-active --quiet "$svc" && {
                echo -e "${Y}▷ 停止服务...${NC}"
                sudo systemctl stop "$svc"
            }
            
            sudo systemctl list-unit-files | grep -q "$svc" && {
                echo -e "${Y}▷ 卸载服务...${NC}"
                sudo "$bin" service uninstall
            }
            
            echo -e "${Y}▷ 删除文件...${NC}"
            [[ "$svc" == "$SERVER_SVC" ]] && \
                sudo rm -rf "$SERVER_DIR" || \
                sudo rm -f "$NODE_DIR"
            
            echo -e "${G}✓ 已卸载${NC}"
            ;;
    esac
}

# 下载并安装组件
install_component() {
    local type=$1 base_url=$2
    
    # 系统检测
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    [[ "$OS" == *"mingw"* || "$OS" == *"cygwin"* ]] && OS="windows"
    ARCH=$(uname -m)
    
    # 架构映射
    case "$ARCH" in
        x86_64)  suffix="amd64_v1" ;;
        i*86)    suffix="386_sse2" ;;
        aarch64|arm64) suffix="arm64_v8.0" ;;
        armv7l)  suffix="arm_7" ;;
        armv6l)  suffix="arm_6" ;;
        armv5l)  suffix="arm_5" ;;
        mips64)  suffix=$(lscpu 2>/dev/null | grep -qi "little endian" && echo "mips64le_hardfloat" || echo "mips64_hardfloat") ;;
        mips)    
            float=$(lscpu 2>/dev/null | grep -qi "FPU" && echo "hardfloat" || echo "softfloat")
            suffix=$(lscpu 2>/dev/null | grep -qi "little endian" && echo "mipsle_$float" || echo "mips_$float")
            ;;
        riscv64) suffix="riscv64_rva20u64" ;;
        s390x)   suffix="s390x" ;;
        *) echo -e "${R}错误: 不支持的架构${NC}" && return ;;
    esac
    
    # 下载文件
    file="${type}_${OS}_${suffix}"
    [[ "$OS" == "windows" ]] && file="${file}.zip" || file="${file}.tar.gz"
    url="${base_url}/${file}"
    
    echo -e "${T}▷ 下载: ${W}$file${NC}"
    echo -e "${S}==================================================${NC}"
    
    # 下载处理
    curl -# -fL -o "$file" "$url" || {
        echo -e "${R}✗ 下载失败!${NC}"
        return
    }
    
    # 解压安装
    [[ "$type" == "server" ]] && target="$SERVER_DIR" || target="${NODE_DIR%/*}"
    sudo mkdir -p "$target"
    [[ "$file" == *.zip ]] && \
        sudo unzip -qo "$file" -d "$target" || \
        sudo tar xzf "$file" -C "$target"
    
    # 清理设置
    rm -f "$file"
    [ -f "$target/$type" ] && sudo chmod 755 "$target/$type" && \
        echo -e "${G}✓ 安装成功${NC}" || \
        echo -e "${R}错误: 文件未找到${NC}"
}

# 安装服务端
install_server() {
    # 安装选项
    [[ -f "$SERVER_BIN" ]] && {
        echo -e "${T}检测到已安装:${NC}"
        echo -e "${O}1. ${W}更新(保留配置)${NC}"
        echo -e "${O}2. ${W}重新安装${NC}"
        echo -e "${O}3. ${W}取消${NC}"
        
        read -rp "选择: " choice
        case $choice in
            2) sudo rm -rf "$SERVER_DIR" ;;
            3) return ;;
            *) update_mode=true ;;
        esac
    }
    
    # 版本选择
    echo -e "${T}选择版本:${NC}"
    echo -e "${O}1. ${W}普通版(默认)${NC}"
    echo -e "${O}2. ${W}商业版${NC}"
    
    read -rp "选择: " choice
    base_url="https://alist.sian.one/direct/gostc/gostc-open"
    [[ "$choice" == 2 ]] && {
        base_url="https://alist.sian.one/direct/gostc"
        echo -e "${Y}▶ 商业版需要授权${NC}"
    }
    
    # 停止服务
    sudo systemctl is-active --quiet "$SERVER_SVC" && {
        echo -e "${Y}▷ 停止服务...${NC}"
        sudo systemctl stop "$SERVER_SVC"
    }
    
    # 安装组件
    install_component "server" "$base_url"
    [ ! -f "$SERVER_BIN" ] && return
    
    # 初始化服务
    sudo systemctl list-units --full -all | grep -Fq "${SERVER_SVC}.service" || {
        echo -e "${Y}▷ 初始化服务...${NC}"
        sudo "$SERVER_BIN" service install
    }
    
    # 启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVER_SVC" >/dev/null 2>&1
    sudo systemctl restart "$SERVER_SVC"
    
    # 状态检查
    sleep 2
    status=$(systemctl is-active "$SERVER_SVC")
    [[ "$status" == "active" ]] && \
        echo -e "${G}✓ 服务已启动${NC}" || \
        echo -e "${Y}⚠ 状态: $status${NC}"
    
    # 初始凭据
    [ ! -f "$SERVER_DIR/config.yml" ] && ! $update_mode && {
        echo -e "${Y}════════════════ 重要 ══════════════════${NC}"
        echo -e "用户名: ${W}admin${NC}"
        echo -e "密码: ${W}admin${NC}"
        echo -e "${Y}首次登录后请修改密码${NC}"
        echo -e "${Y}════════════════════════════════════════${NC}"
    }
}

# 安装节点/客户端
install_node() {
    # 类型选择
    echo -e "${T}选择类型:${NC}"
    echo -e "${O}1. ${W}节点(默认)${NC}"
    echo -e "${O}2. ${W}客户端${NC}"
    echo -e "${O}0. ${W}返回${NC}"
    
    read -rp "选择: " choice
    [[ "$choice" == 0 ]] && return
    [[ "$choice" == 2 ]] && type="client" || type="node"
    
    # 安装组件
    install_component "gostc" "https://alist.sian.one/direct/gostc"
    [ ! -f "$NODE_DIR" ] && return
    
    # 配置
    echo -e "${T}▶ 配置${type}${NC}"
    echo -e "${S}==================================================${NC}"
    
    # 公共配置
    read -p "$(echo -e "${T}▷ 使用TLS? ${NC}(y/n): ")" tls_choice
    tls=; [[ "$tls_choice" =~ ^[Yy]$ ]] && tls="--tls=true"
    
    server="127.0.0.1:8080"
    read -p "$(echo -e "${T}▷ 服务器地址 ${W}[$server]${T}: ${NC}")" input
    server=${input:-$server}
    
    key=""
    while [ -z "$key" ]; do
        read -p "$(echo -e "${T}▷ 输入密钥: ${NC}")" key
    done
    
    # 节点特殊配置
    proxy=""
    [[ "$type" == "node" ]] && {
        read -p "$(echo -e "${T}▷ 使用网关代理? ${NC}(y/n): ")" proxy_choice
        [[ "$proxy_choice" =~ ^[Yy]$ ]] && {
            while [ -z "$proxy" ]; do
                read -p "$(echo -e "${T}▷ 网关地址(http/https): ${NC}")" proxy
                [[ "$proxy" =~ ^https?:// ]] || proxy=""
            done
            proxy="--proxy-base-url $proxy"
        }
        extra_flags="-s"
    }
    
    # 安装命令
    cmd="sudo $NODE_DIR install $tls -addr $server $extra_flags -key $key $proxy"
    echo ""
    eval "$cmd" || {
        echo -e "${R}✗ 配置失败${NC}"
        return
    }
    
    # 启动服务
    sudo systemctl start "$NODE_SVC"
    sleep 1
    sudo systemctl is-active --quiet "$NODE_SVC" && \
        echo -e "${G}✓ 服务已启动${NC}" || \
        echo -e "${Y}⚠ 启动异常${NC}"
}

# 更新节点
update_node() {
    [ ! -f "$NODE_DIR" ] && echo -e "${R}✗ 未安装${NC}" && return
    
    # 停止服务
    sudo systemctl is-active --quiet "$NODE_SVC" && {
        echo -e "${Y}▷ 停止服务...${NC}"
        sudo systemctl stop "$NODE_SVC"
    }
    
    # 重新安装
    install_component "gostc" "https://alist.sian.one/direct/gostc"
    
    # 重启服务
    sudo systemctl start "$NODE_SVC"
    sleep 1
    sudo systemctl is-active --quiet "$NODE_SVC" && \
        echo -e "${G}✓ 更新成功${NC}" || \
        echo -e "${Y}⚠ 启动异常${NC}"
}

# 检查更新
check_update() {
    echo -e "${Y}▶ 检查更新...${NC}"
    latest=$(curl -s "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" |
             awk -F'"' '/TOOL_VERSION=/{print $2; exit}')
    
    [[ -z "$latest" ]] && echo -e "${R}✗ 获取失败${NC}" && return
    [[ "$latest" == "$TOOL_VERSION" ]] && echo -e "${G}✓ 已是最新版${NC}" && return
    
    echo -e "${T}当前: ${W}v$TOOL_VERSION${NC}"
    echo -e "${T}最新: ${W}v$latest${NC}"
    read -rp "更新? (y/n, 默认y): " confirm
    [[ "$confirm" == "n" ]] && return
    
    sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${G}✓ 已更新到 v$latest${NC}"
        echo -e "${T}请重新运行${NC}"
        exit 0
    }
    echo -e "${R}✗ 更新失败${NC}"
}

# 自动更新检查
auto_update() {
    echo -e "${Y}▶ 检查工具箱更新...${NC}"
    latest=$(curl -s "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" |
             awk -F'"' '/TOOL_VERSION=/{print $2; exit}')
    
    [[ -z "$latest" ]] && return
    [[ "$latest" == "$TOOL_VERSION" ]] && return
    
    echo -e "${G}✓ 发现新版本: ${W}v$latest${NC}"
    sudo curl -fL "https://git.wavee.cn/raw.githubusercontent.com/dxiaom/gotool/refs/heads/main/install.sh" -o "$TOOL_PATH" && {
        sudo chmod +x "$TOOL_PATH"
        echo -e "${G}✓ 已更新到 v$latest${NC}"
        echo -e "${T}请重新运行${NC}"
        exit 0
    }
}

# 显示主菜单
show_menu() {
    echo -e "${S}==================================================${NC}"
    echo -e "${T}          GOSTC 工具箱 v$TOOL_VERSION           ${NC}"
    echo -e "${S}==================================================${NC}"
    echo -e "${T}服务端状态: $(service_status "$SERVER_SVC" "$SERVER_BIN")${NC}"
    echo -e "${T}节点状态: $(service_status "$NODE_SVC" "$NODE_DIR")${NC}"
    echo -e "${S}==================================================${NC}"
    echo -e "${O}1. ${W}服务端管理${NC}"
    echo -e "${O}2. ${W}节点/客户端管理${NC}"
    echo -e "${O}3. ${W}检查更新${NC}"
    echo -e "${O}4. ${W}卸载工具箱${NC}"
    echo -e "${O}0. ${W}退出${NC}"
    echo -e "${S}==================================================${NC}"
}

# 服务管理菜单
service_menu() {
    local title=$1 svc=$2 bin=$3 install_func=$4
    
    while :; do
        echo -e "${S}==================================================${NC}"
        echo -e "${T}$title $(service_status "$svc" "$bin")${NC}"
        echo -e "${S}==================================================${NC}"
        [[ "$svc" == "$SERVER_SVC" ]] && 
            echo -e "${O}1. ${W}安装/更新${NC}" || 
            echo -e "${O}1. ${W}安装${NC}"
        echo -e "${O}2. ${W}启动${NC}"
        echo -e "${O}3. ${W}重启${NC}"
        echo -e "${O}4. ${W}停止${NC}"
        echo -e "${O}5. ${W}卸载${NC}"
        [[ "$svc" == "$NODE_SVC" ]] && echo -e "${O}6. ${W}更新${NC}"
        echo -e "${O}0. ${W}返回${NC}"
        echo -e "${S}==================================================${NC}"
        
        read -rp "选择: " choice
        case $choice in
            1) $install_func ;;
            2) service_action "$svc" "$bin" start ;;
            3) service_action "$svc" "$bin" restart ;;
            4) service_action "$svc" "$bin" stop ;;
            5) service_action "$svc" "$bin" uninstall ;;
            6) [[ "$svc" == "$NODE_SVC" ]] && update_node || echo -e "${R}无效选项${NC}" ;;
            0) break ;;
            *) echo -e "${R}无效选项${NC}" ;;
        esac
    done
}

# 主程序
main() {
    auto_update
    
    while :; do
        show_menu
        read -rp "选择: " choice
        
        case $choice in
            1) service_menu "服务端管理" "$SERVER_SVC" "$SERVER_BIN" install_server ;;
            2) service_menu "节点/客户端管理" "$NODE_SVC" "$NODE_DIR" install_node ;;
            3) check_update ;;
            4) 
                echo -e "${Y}▶ 确定卸载工具箱? ${NC}(y/n)"
                read -rp "确认: " confirm
                [[ "$confirm" == "y" ]] && sudo rm -f "$TOOL_PATH" && \
                    echo -e "${G}✓ 已卸载${NC}" && exit 0
                ;;
            0) echo -e "${T}▶ 再见!${NC}" && exit 0 ;;
            *) echo -e "${R}无效选择${NC}" ;;
        esac
    done
}

# 启动
main
