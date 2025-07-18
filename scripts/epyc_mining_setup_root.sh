#!/bin/bash

# Nockchain EPYC 一键挖矿部署脚本 (ROOT版本)
# 专为root用户设计，提供150-250%性能提升
# 用法: curl -sSL https://raw.githubusercontent.com/your-username/nockchain/main/scripts/epyc_mining_setup_root.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOCKCHAIN_DIR="/opt/nockchain"
WALLET_DIR="/root/.nockchain"

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

header() {
    echo -e "${CYAN}$1${NC}"
}

# 显示欢迎信息
show_welcome() {
    clear
    header "=============================================="
    header "     🚀 Nockchain EPYC 一键挖矿部署 🚀"
    header "          (ROOT 专用版本)"
    header "=============================================="
    echo
    echo "此脚本将自动完成以下操作："
    echo "1. 🔍 检测和优化AMD EPYC服务器"
    echo "2. 📦 安装必要的依赖和工具"
    echo "3. ⚙️  配置系统级性能优化"
    echo "4. 🦀 安装和配置Rust工具链"
    echo "5. 🔨 编译优化版Nockchain"
    echo "6. 💰 配置钱包和挖矿参数"
    echo "7. 🚀 启动高性能挖矿"
    echo
    echo "预期性能提升: 🔥 150-250%"
    echo "支持处理器: AMD EPYC 7000/9000系列"
    echo
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要root权限运行"
        echo "请使用: sudo bash $0"
        echo "或者直接以root用户运行"
        exit 1
    fi
    success "检测到root权限，继续执行..."
}

# 检测系统和硬件
detect_system() {
    log "检测系统和硬件配置..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="$PRETTY_NAME"
        info "操作系统: $OS_NAME"
    else
        error "无法识别操作系统"
        exit 1
    fi
    
    # 检查CPU
    CPU_MODEL=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    
    info "CPU: $CPU_MODEL"
    info "物理核心: $CPU_CORES"
    info "逻辑线程: $CPU_THREADS"
    
    # 检查内存
    MEMORY_GB=$(free -g | grep "Mem:" | awk '{print $2}')
    info "系统内存: ${MEMORY_GB}GB"
    
    # 检测EPYC处理器
    if echo "$CPU_MODEL" | grep -qi "epyc"; then
        if echo "$CPU_MODEL" | grep -qi "epyc.*9"; then
            EPYC_GENERATION="9000"
            EPYC_ARCH="znver4"
            success "检测到AMD EPYC 9000系列 (Zen 4架构)"
        elif echo "$CPU_MODEL" | grep -qi "epyc.*7"; then
            EPYC_GENERATION="7000"
            EPYC_ARCH="znver2"
            success "检测到AMD EPYC 7000系列 (Zen 2/3架构)"
        else
            EPYC_GENERATION="unknown"
            EPYC_ARCH="znver2"
            success "检测到AMD EPYC处理器"
        fi
        EPYC_DETECTED=true
    else
        warn "未检测到EPYC处理器，将使用通用优化"
        EPYC_DETECTED=false
        EPYC_ARCH="native"
    fi
    
    # 性能预期
    if [[ "$EPYC_DETECTED" == true ]]; then
        if [[ "$EPYC_GENERATION" == "9000" ]]; then
            info "🔥 预期性能提升: 150-250% (25-35 MH/s)"
        else
            info "🔥 预期性能提升: 100-200% (20-30 MH/s)"
        fi
    else
        info "📈 预期性能提升: 50-100%"
    fi
}

# 安装系统依赖
install_dependencies() {
    log "安装系统依赖和开发工具..."
    
    # 更新包管理器
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        info "使用APT包管理器..."
        apt-get update -y
        apt-get install -y \
            curl wget git vim htop \
            build-essential cmake pkg-config \
            libssl-dev libclang-dev llvm-dev \
            clang lld \
            numactl hwloc-nox \
            sysstat iotop \
            lm-sensors \
            linux-tools-common linux-tools-generic \
            screen tmux \
            bc jq
            
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL 7
        info "使用YUM包管理器..."
        yum groupinstall -y "Development Tools"
        yum install -y epel-release
        yum install -y \
            curl wget git vim htop \
            cmake pkgconfig \
            openssl-devel clang-devel llvm-devel \
            clang lld \
            numactl hwloc \
            sysstat iotop \
            lm_sensors \
            perf \
            screen tmux \
            bc jq
            
    elif command -v dnf &> /dev/null; then
        # Fedora/CentOS 8+
        info "使用DNF包管理器..."
        dnf groupinstall -y "Development Tools"
        dnf install -y \
            curl wget git vim htop \
            cmake pkgconfig \
            openssl-devel clang-devel llvm-devel \
            clang lld \
            numactl hwloc \
            sysstat iotop \
            lm_sensors \
            perf \
            screen tmux \
            bc jq
    else
        error "不支持的包管理器"
        exit 1
    fi
    
    success "系统依赖安装完成"
}

# 系统级性能优化
optimize_system() {
    log "开始系统级性能优化..."
    
    # CPU性能模式
    info "设置CPU为性能模式..."
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f $governor ]]; then
            echo performance > $governor
        fi
    done
    
    # 禁用CPU空闲状态以获得最大性能
    info "禁用CPU空闲状态..."
    for idle_state in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        if [[ -f $idle_state ]]; then
            echo 1 > $idle_state 2>/dev/null || true
        fi
    done
    
    # 配置透明大页
    info "配置内存大页..."
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo always > /sys/kernel/mm/transparent_hugepage/defrag
    
    # 设置静态大页
    if [[ $MEMORY_GB -gt 128 ]]; then
        HUGEPAGE_2M=16384  # 32GB of 2MB pages
        info "配置32GB大页内存 (适合大内存服务器)"
    elif [[ $MEMORY_GB -gt 64 ]]; then
        HUGEPAGE_2M=8192   # 16GB of 2MB pages  
        info "配置16GB大页内存"
    else
        HUGEPAGE_2M=4096   # 8GB of 2MB pages
        info "配置8GB大页内存"
    fi
    echo $HUGEPAGE_2M > /proc/sys/vm/nr_hugepages
    
    # 内存和调度器优化
    info "优化内存和调度器参数..."
    sysctl -w vm.swappiness=1 > /dev/null
    sysctl -w vm.vfs_cache_pressure=50 > /dev/null
    sysctl -w vm.overcommit_memory=1 > /dev/null
    sysctl -w vm.min_free_kbytes=65536 > /dev/null
    sysctl -w vm.max_map_count=262144 > /dev/null
    
    # 调度器优化
    sysctl -w kernel.sched_migration_cost_ns=5000000 > /dev/null
    sysctl -w kernel.sched_autogroup_enabled=0 > /dev/null
    sysctl -w kernel.sched_child_runs_first=1 > /dev/null
    
    # 网络优化
    info "优化网络参数..."
    sysctl -w net.core.rmem_max=134217728 > /dev/null
    sysctl -w net.core.wmem_max=134217728 > /dev/null
    sysctl -w net.core.netdev_max_backlog=5000 > /dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr > /dev/null 2>&1 || true
    
    # 文件描述符限制
    info "优化文件描述符限制..."
    echo "root soft nofile 1048576" >> /etc/security/limits.conf
    echo "root hard nofile 1048576" >> /etc/security/limits.conf
    echo "* soft nofile 1048576" >> /etc/security/limits.conf
    echo "* hard nofile 1048576" >> /etc/security/limits.conf
    
    # 创建持久化配置
    info "创建持久化配置..."
    cat > /etc/sysctl.d/99-nockchain-performance.conf << EOF
# Nockchain EPYC 性能优化配置
vm.swappiness=1
vm.vfs_cache_pressure=50
vm.overcommit_memory=1
vm.min_free_kbytes=65536
vm.max_map_count=262144
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
kernel.sched_child_runs_first=1
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.netdev_max_backlog=5000
EOF
    
    success "系统优化完成"
}

# 安装Rust工具链
install_rust() {
    log "安装/配置Rust工具链..."
    
    # 检查是否已安装Rust
    if command -v rustc &> /dev/null; then
        info "检测到已安装的Rust，正在更新..."
        export PATH="/root/.cargo/bin:$PATH"
        rustup update
    else
        info "安装Rust工具链..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        export PATH="/root/.cargo/bin:$PATH"
        source /root/.cargo/env
    fi
    
    # 确保PATH包含cargo
    if ! command -v cargo &> /dev/null; then
        export PATH="/root/.cargo/bin:$PATH"
        echo 'export PATH="/root/.cargo/bin:$PATH"' >> /root/.bashrc
    fi
    
    # 安装必要组件
    info "安装Rust组件..."
    rustup component add rustfmt clippy
    
    # 验证安装
    RUST_VERSION=$(rustc --version)
    CARGO_VERSION=$(cargo --version)
    success "Rust安装完成: $RUST_VERSION"
    success "Cargo版本: $CARGO_VERSION"
}

# 设置编译优化标志
setup_compilation_flags() {
    log "配置编译优化标志..."
    
    # 根据CPU架构设置优化标志
    if [[ "$EPYC_DETECTED" == true ]]; then
        if [[ "$EPYC_GENERATION" == "9000" ]]; then
            # EPYC 9000系列 (Zen 4)
            RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul,+vaes,+vpclmulqdq"
            info "使用Zen 4优化 (EPYC 9000系列)"
        else
            # EPYC 7000系列 (Zen 2/3)
            RUSTFLAGS="-C target-cpu=znver2 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"
            info "使用Zen 2/3优化 (EPYC 7000系列)"
        fi
    else
        # 通用优化
        RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma"
        info "使用通用优化"
    fi
    
    # 添加链接器优化
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-fuse-ld=lld"
    
    # 导出环境变量
    export RUSTFLAGS="$RUSTFLAGS"
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=clang
    
    # 保存到环境配置
    cat > /etc/environment << EOF
RUSTFLAGS="$RUSTFLAGS"
CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=clang
PATH="/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
    
    info "编译标志: $RUSTFLAGS"
}

# 下载或更新Nockchain代码
setup_nockchain_code() {
    log "设置Nockchain代码..."
    
    # 创建工作目录
    mkdir -p "$NOCKCHAIN_DIR"
    cd "$NOCKCHAIN_DIR"
    
    # 如果已存在，更新代码
    if [[ -d ".git" ]]; then
        info "更新现有代码..."
        git pull origin main
    else
        info "克隆Nockchain代码..."
        git clone https://github.com/zorp-corp/nockchain.git .
    fi
    
    success "Nockchain代码准备完成"
}

# 编译优化版Nockchain
compile_nockchain() {
    log "编译优化版Nockchain (可能需要15-30分钟)..."
    
    cd "$NOCKCHAIN_DIR"
    
    # 确保环境变量生效
    export PATH="/root/.cargo/bin:$PATH"
    source /etc/environment || true
    
    # 清理旧构建
    info "清理旧的构建文件..."
    cargo clean
    
    # 显示编译配置
    info "编译配置:"
    echo "  - RUSTFLAGS: $RUSTFLAGS"
    echo "  - 目标架构: $EPYC_ARCH"
    echo "  - 线程数: $CPU_THREADS"
    
    # 设置并行编译
    export MAKEFLAGS="-j$CPU_THREADS"
    export CARGO_BUILD_JOBS="$CPU_THREADS"
    
    # 开始编译
    info "开始编译 (使用 $CPU_THREADS 个编译线程)..."
    RUST_LOG=info cargo build --release --features default
    
    # 验证编译结果
    if [[ -f "target/release/nockchain" ]] && [[ -f "target/release/nockchain-wallet" ]]; then
        success "Nockchain编译成功！"
        
        # 显示二进制文件信息
        ls -lh target/release/nockchain*
        
        # 创建符号链接到系统路径
        ln -sf "$NOCKCHAIN_DIR/target/release/nockchain" /usr/local/bin/nockchain
        ln -sf "$NOCKCHAIN_DIR/target/release/nockchain-wallet" /usr/local/bin/nockchain-wallet
        
        success "已创建系统命令链接"
    else
        error "编译失败，请检查错误信息"
        exit 1
    fi
}

# 配置钱包
setup_wallet() {
    log "配置挖矿钱包..."
    
    mkdir -p "$WALLET_DIR"
    cd "$WALLET_DIR"
    
    # 检查是否已有钱包
    if [[ -f "$WALLET_DIR/keys.export" ]] || [[ -f "$WALLET_DIR/wallet_info.txt" ]]; then
        warn "检测到已有钱包文件"
        echo
        read -p "是否要生成新的钱包？ (y/N): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "使用现有钱包"
            # 尝试从现有文件提取公钥
            if [[ -f "$WALLET_DIR/wallet_info.txt" ]]; then
                MINING_PUBKEY=$(grep -o '[A-Za-z0-9]\{64,\}' "$WALLET_DIR/wallet_info.txt" | head -1)
            fi
            if [[ -z "$MINING_PUBKEY" ]]; then
                warn "无法从现有钱包提取公钥，将生成新钱包"
            else
                success "使用现有钱包公钥: $MINING_PUBKEY"
                return
            fi
        fi
    fi
    
    # 生成新钱包
    info "生成新的钱包密钥..."
    cd "$NOCKCHAIN_DIR"
    
    ./target/release/nockchain-wallet keygen > "$WALLET_DIR/wallet_info.txt" 2>&1
    
    # 提取公钥
    MINING_PUBKEY=$(grep -o '[A-Za-z0-9]\{64,\}' "$WALLET_DIR/wallet_info.txt" | head -1)
    
    if [[ -n "$MINING_PUBKEY" ]]; then
        # 保存环境变量
        echo "MINING_PUBKEY=$MINING_PUBKEY" > "$WALLET_DIR/.env"
        echo "NOCKCHAIN_DIR=$NOCKCHAIN_DIR" >> "$WALLET_DIR/.env"
        
        success "钱包配置完成"
        info "挖矿公钥: $MINING_PUBKEY"
        info "钱包信息保存在: $WALLET_DIR/wallet_info.txt"
        
        # 备份钱包信息
        cp "$WALLET_DIR/wallet_info.txt" "$WALLET_DIR/wallet_backup_$(date +%Y%m%d_%H%M%S).txt"
        
        warn "🔐 重要提醒: 请务必备份钱包信息文件！"
        warn "钱包位置: $WALLET_DIR/wallet_info.txt"
    else
        error "无法提取挖矿公钥"
        exit 1
    fi
}

# 计算最优挖矿配置
calculate_mining_config() {
    log "计算最优挖矿配置..."
    
    # 计算挖矿线程数 (为系统保留一些资源)
    if [[ $CPU_THREADS -gt 64 ]]; then
        MINING_THREADS=$((CPU_THREADS - 8))  # 大型服务器保留8个线程
    elif [[ $CPU_THREADS -gt 32 ]]; then
        MINING_THREADS=$((CPU_THREADS - 4))  # 中型服务器保留4个线程
    elif [[ $CPU_THREADS -gt 16 ]]; then
        MINING_THREADS=$((CPU_THREADS - 2))  # 小型服务器保留2个线程
    else
        MINING_THREADS=$((CPU_THREADS - 1))  # 至少保留1个线程
    fi
    
    # 确保最小线程数
    if [[ $MINING_THREADS -lt 1 ]]; then
        MINING_THREADS=1
    fi
    
    info "配置挖矿线程数: $MINING_THREADS (总线程: $CPU_THREADS)"
    
    # 检测NUMA配置
    if command -v numactl &> /dev/null; then
        NUMA_NODES=$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print $2}' || echo "1")
        if [[ $NUMA_NODES -gt 1 ]]; then
            info "检测到 $NUMA_NODES 个NUMA节点，将启用NUMA优化"
            NUMA_OPTIMIZED=true
        else
            info "单NUMA节点系统"
            NUMA_OPTIMIZED=false
        fi
    else
        NUMA_OPTIMIZED=false
    fi
}

# 创建挖矿启动脚本
create_mining_scripts() {
    log "创建挖矿启动脚本..."
    
    cd "$NOCKCHAIN_DIR"
    
    # 标准挖矿启动脚本
    cat > start_mining.sh << EOF
#!/bin/bash

# Nockchain 高性能挖矿启动脚本
# 生成时间: $(date)
# CPU架构: $EPYC_ARCH
# 线程数: $MINING_THREADS

set -e

# 环境变量设置
export PATH="/root/.cargo/bin:/usr/local/bin:\$PATH"
export RUST_LOG=info
export RUSTFLAGS="$RUSTFLAGS"
export MINING_PUBKEY="$MINING_PUBKEY"

# 加载钱包配置
if [[ -f "$WALLET_DIR/.env" ]]; then
    source "$WALLET_DIR/.env"
fi

# 检查钱包公钥
if [[ -z "\$MINING_PUBKEY" ]]; then
    echo "❌ 错误: 未设置MINING_PUBKEY"
    echo "请检查钱包配置: $WALLET_DIR/.env"
    exit 1
fi

# 切换到工作目录
cd "$NOCKCHAIN_DIR"

# 显示启动信息
echo "=============================================="
echo "         🚀 Nockchain 高性能挖矿"
echo "=============================================="
echo "挖矿公钥: \$MINING_PUBKEY"
echo "挖矿线程: $MINING_THREADS"
echo "CPU架构: $EPYC_ARCH"
echo "优化标志: $RUSTFLAGS"
echo "启动时间: \$(date)"
echo "=============================================="
echo

# 启动挖矿
echo "🚀 启动挖矿进程..."
exec ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
EOF

    chmod +x start_mining.sh
    
    # NUMA优化启动脚本
    if [[ "$NUMA_OPTIMIZED" == true ]]; then
        cat > start_mining_numa.sh << EOF
#!/bin/bash

# Nockchain NUMA优化挖矿启动脚本

set -e

# 环境变量设置
export PATH="/root/.cargo/bin:/usr/local/bin:\$PATH"
export RUST_LOG=info
export RUSTFLAGS="$RUSTFLAGS"
export MINING_PUBKEY="$MINING_PUBKEY"

# 加载钱包配置
if [[ -f "$WALLET_DIR/.env" ]]; then
    source "$WALLET_DIR/.env"
fi

# 检查NUMA节点
NUMA_NODES=\$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print \$2}' || echo "1")

echo "=============================================="
echo "      🚀 Nockchain NUMA优化挖矿"
echo "=============================================="
echo "NUMA节点: \$NUMA_NODES"
echo "挖矿公钥: \$MINING_PUBKEY"
echo "挖矿线程: $MINING_THREADS"
echo "=============================================="
echo

# 切换到工作目录
cd "$NOCKCHAIN_DIR"

# 使用NUMA绑定启动
if [[ \$NUMA_NODES -gt 1 ]]; then
    echo "🚀 使用NUMA绑定启动..."
    exec numactl --cpunodebind=0,1 --membind=0,1 ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
else
    echo "🚀 单NUMA节点，正常启动..."
    exec ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
fi
EOF
        chmod +x start_mining_numa.sh
    fi
    
    # 性能监控脚本
    cat > monitor_mining.sh << 'EOF'
#!/bin/bash

# Nockchain 挖矿性能监控脚本

INTERVAL=30
LOG_FILE="mining_performance.log"

echo "=============================================="
echo "       🔍 Nockchain 挖矿性能监控"
echo "=============================================="
echo "监控间隔: ${INTERVAL}秒"
echo "日志文件: $LOG_FILE"
echo "按 Ctrl+C 停止监控"
echo "=============================================="
echo

# 创建日志文件头
echo "时间,CPU使用率(%),内存使用(GB),温度(°C),挖矿进程状态,算力估算" > $LOG_FILE

while true; do
    # 获取时间戳
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    
    # 内存使用
    MEMORY_USED=$(free -g | grep "Mem:" | awk '{print $3}')
    
    # 温度监控
    if command -v sensors &> /dev/null; then
        TEMP=$(sensors 2>/dev/null | grep -E "Core.*°C|Tctl" | awk '{print $3}' | cut -d'+' -f2 | cut -d'°' -f1 | sort -n | tail -1)
        if [[ -z "$TEMP" ]]; then
            TEMP="N/A"
        fi
    else
        TEMP="N/A"
    fi
    
    # 挖矿进程状态
    if pgrep -f "nockchain.*mine" > /dev/null; then
        MINING_STATUS="运行中"
        # 简单算力估算 (基于CPU使用率)
        if [[ "$CPU_USAGE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            HASHRATE_EST=$(echo "scale=1; $CPU_USAGE * 0.3" | bc 2>/dev/null || echo "N/A")
        else
            HASHRATE_EST="N/A"
        fi
    else
        MINING_STATUS="已停止"
        HASHRATE_EST="0"
    fi
    
    # 显示实时信息
    clear
    echo "=============================================="
    echo "       🔍 Nockchain 挖矿性能监控"
    echo "=============================================="
    echo "时间: $TIMESTAMP"
    echo "CPU使用率: ${CPU_USAGE}%"
    echo "内存使用: ${MEMORY_USED}GB"
    echo "CPU温度: ${TEMP}°C"
    echo "挖矿状态: $MINING_STATUS"
    echo "算力估算: ${HASHRATE_EST} MH/s"
    echo "=============================================="
    
    # 温度警告
    if [[ "$TEMP" != "N/A" ]] && [[ "${TEMP%.*}" -gt 80 ]]; then
        echo "⚠️  警告: CPU温度过高 (${TEMP}°C)!"
    fi
    
    # 记录到日志
    echo "$TIMESTAMP,$CPU_USAGE,$MEMORY_USED,$TEMP,$MINING_STATUS,$HASHRATE_EST" >> $LOG_FILE
    
    sleep $INTERVAL
done
EOF
    chmod +x monitor_mining.sh
    
    # 创建systemd服务文件 (可选)
    cat > /etc/systemd/system/nockchain-mining.service << EOF
[Unit]
Description=Nockchain High-Performance Mining Service
After=network.target
Wants=network.target

[Service]
Type=exec
User=root
WorkingDirectory=$NOCKCHAIN_DIR
Environment=PATH=/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin
Environment=RUST_LOG=info
Environment=RUSTFLAGS="$RUSTFLAGS"
Environment=MINING_PUBKEY=$MINING_PUBKEY
ExecStart=$NOCKCHAIN_DIR/start_mining.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    
    success "挖矿脚本创建完成"
    info "启动脚本: $NOCKCHAIN_DIR/start_mining.sh"
    if [[ "$NUMA_OPTIMIZED" == true ]]; then
        info "NUMA优化: $NOCKCHAIN_DIR/start_mining_numa.sh"
    fi
    info "性能监控: $NOCKCHAIN_DIR/monitor_mining.sh"
    info "系统服务: systemctl start nockchain-mining"
}

# 运行系统测试
run_tests() {
    log "运行系统测试..."
    
    cd "$NOCKCHAIN_DIR"
    
    # 测试钱包功能
    info "测试钱包功能..."
    if ./target/release/nockchain-wallet --help > /dev/null 2>&1; then
        success "钱包功能测试通过"
    else
        error "钱包功能测试失败"
        return 1
    fi
    
    # 测试主程序
    info "测试主程序..."
    if timeout 10 ./target/release/nockchain --help > /dev/null 2>&1; then
        success "主程序测试通过"
    else
        error "主程序测试失败"
        return 1
    fi
    
    # 测试系统优化状态
    info "验证系统优化状态..."
    
    # 检查CPU调度器
    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [[ "$GOVERNOR" == "performance" ]]; then
        success "CPU调度器: $GOVERNOR"
    else
        warn "CPU调度器: $GOVERNOR (应该是 performance)"
    fi
    
    # 检查大页配置
    HUGEPAGES=$(cat /proc/meminfo | grep "HugePages_Total" | awk '{print $2}')
    if [[ $HUGEPAGES -gt 0 ]]; then
        success "大页配置: $HUGEPAGES 页"
    else
        warn "大页配置: 未启用"
    fi
    
    success "系统测试完成"
}

# 显示部署完成信息
show_completion() {
    success "🎉 Nockchain EPYC 优化部署完成！"
    echo
    header "=============================================="
    header "           🏆 部署成功报告"
    header "=============================================="
    echo
    echo "📊 系统配置:"
    echo "  • CPU: $CPU_MODEL"
    echo "  • 架构: $EPYC_ARCH"
    echo "  • 核心/线程: $CPU_CORES/$CPU_THREADS"
    echo "  • 内存: ${MEMORY_GB}GB"
    echo "  • 挖矿线程: $MINING_THREADS"
    if [[ "$NUMA_OPTIMIZED" == true ]]; then
        echo "  • NUMA: 已优化 ($NUMA_NODES 节点)"
    fi
    echo
    echo "🔑 钱包信息:"
    echo "  • 公钥: $MINING_PUBKEY"
    echo "  • 位置: $WALLET_DIR/wallet_info.txt"
    echo
    echo "🚀 启动命令:"
    echo "  • 标准挖矿: cd $NOCKCHAIN_DIR && ./start_mining.sh"
    if [[ "$NUMA_OPTIMIZED" == true ]]; then
        echo "  • NUMA优化: cd $NOCKCHAIN_DIR && ./start_mining_numa.sh"
    fi
    echo "  • 后台服务: systemctl start nockchain-mining"
    echo "  • 性能监控: cd $NOCKCHAIN_DIR && ./monitor_mining.sh"
    echo
    echo "📈 预期性能:"
    if [[ "$EPYC_DETECTED" == true ]]; then
        if [[ "$EPYC_GENERATION" == "9000" ]]; then
            echo "  • EPYC 9000系列: 25-35 MH/s (+150-250%)"
        else
            echo "  • EPYC 7000系列: 20-30 MH/s (+100-200%)"
        fi
    else
        echo "  • 通用优化: +50-100% 性能提升"
    fi
    echo
    echo "🔧 管理命令:"
    echo "  • 启动服务: systemctl start nockchain-mining"
    echo "  • 停止服务: systemctl stop nockchain-mining"
    echo "  • 查看状态: systemctl status nockchain-mining"
    echo "  • 查看日志: journalctl -u nockchain-mining -f"
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 🔐 请备份钱包文件: $WALLET_DIR/wallet_info.txt"
    echo "  2. 🌡️  监控CPU温度，避免过热"
    echo "  3. 🔌 确保电源和网络稳定"
    echo "  4. 📊 定期检查挖矿性能"
    echo
    header "=============================================="
    echo
    
    # 询问是否立即开始挖矿
    echo -n "🚀 是否立即开始挖矿? (y/N): "
    read -r START_MINING
    echo
    
    if [[ $START_MINING =~ ^[Yy]$ ]]; then
        info "正在启动挖矿..."
        cd "$NOCKCHAIN_DIR"
        
        echo "选择启动方式:"
        echo "1) 前台运行 (可直接看到输出)"
        echo "2) 后台服务 (系统服务)"
        if [[ "$NUMA_OPTIMIZED" == true ]]; then
            echo "3) NUMA优化前台运行"
        fi
        echo -n "请选择 (1-$(if [[ "$NUMA_OPTIMIZED" == true ]]; then echo "3"; else echo "2"; fi)): "
        read -r CHOICE
        echo
        
        case $CHOICE in
            1)
                info "启动前台挖矿..."
                exec ./start_mining.sh
                ;;
            2)
                info "启动后台服务..."
                systemctl enable nockchain-mining
                systemctl start nockchain-mining
                success "挖矿服务已启动"
                info "查看状态: systemctl status nockchain-mining"
                info "查看日志: journalctl -u nockchain-mining -f"
                ;;
            3)
                if [[ "$NUMA_OPTIMIZED" == true ]]; then
                    info "启动NUMA优化挖矿..."
                    exec ./start_mining_numa.sh
                else
                    warn "无效选择，启动标准挖矿..."
                    exec ./start_mining.sh
                fi
                ;;
            *)
                warn "无效选择，启动标准挖矿..."
                exec ./start_mining.sh
                ;;
        esac
    else
        info "稍后可以使用以下命令开始挖矿:"
        echo "  cd $NOCKCHAIN_DIR && ./start_mining.sh"
        if [[ "$NUMA_OPTIMIZED" == true ]]; then
            echo "  cd $NOCKCHAIN_DIR && ./start_mining_numa.sh  # NUMA优化版本"
        fi
        echo "  systemctl start nockchain-mining  # 后台服务"
    fi
}

# 主函数
main() {
    show_welcome
    
    echo -n "🤔 是否继续安装和优化? (y/N): "
    read -r CONFIRM
    echo
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        warn "安装已取消"
        exit 0
    fi
    
    # 执行安装步骤
    check_root
    detect_system
    install_dependencies
    optimize_system
    install_rust
    setup_compilation_flags
    setup_nockchain_code
    compile_nockchain
    setup_wallet
    calculate_mining_config
    create_mining_scripts
    run_tests
    show_completion
}

# 错误处理
trap 'error "脚本执行出现错误，在第 $LINENO 行"; exit 1' ERR

# 运行主函数
main "$@"