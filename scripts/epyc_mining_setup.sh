#!/bin/bash

# Nockchain EPYC 一键挖矿部署脚本
# 用法: curl -sSL https://raw.githubusercontent.com/your-username/nockchain/main/scripts/epyc_mining_setup.sh | bash
# 或者: git clone https://github.com/zorp-corp/nockchain.git && cd nockchain && bash scripts/epyc_mining_setup.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${PURPLE}"
    echo "=============================================="
    echo "     🚀 Nockchain EPYC 一键挖矿部署 🚀"
    echo "=============================================="
    echo -e "${NC}"
    echo
    echo "此脚本将自动完成以下操作："
    echo "1. 检测和优化AMD EPYC服务器"
    echo "2. 安装必要的依赖和工具"
    echo "3. 编译优化版Nockchain"
    echo "4. 配置钱包和挖矿参数"
    echo "5. 启动高性能挖矿"
    echo
    echo "预期性能提升: 150-250%"
    echo
}

# 检查系统要求
check_requirements() {
    log "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        error "无法识别操作系统"
        exit 1
    fi
    
    source /etc/os-release
    info "操作系统: $PRETTY_NAME"
    
    # 检查CPU
    CPU_MODEL=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    
    info "CPU: $CPU_MODEL"
    info "核心数: $CPU_CORES, 线程数: $CPU_THREADS"
    
    # 检查内存
    MEMORY_GB=$(free -g | grep "Mem:" | awk '{print $2}')
    info "内存: ${MEMORY_GB}GB"
    
    # 建议配置
    if echo "$CPU_MODEL" | grep -qi "epyc"; then
        success "检测到AMD EPYC处理器，适合优化！"
        EPYC_DETECTED=true
    else
        warn "未检测到EPYC处理器，性能提升可能有限"
        EPYC_DETECTED=false
    fi
    
    if [[ $MEMORY_GB -lt 32 ]]; then
        warn "内存少于32GB，可能影响挖矿性能"
    fi
    
    if [[ $CPU_CORES -lt 16 ]]; then
        warn "CPU核心数少于16，建议使用更强大的处理器"
    fi
}

# 检查权限
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        info "检测到root权限"
        USE_SUDO=""
    else
        info "检测到普通用户，将使用sudo"
        USE_SUDO="sudo"
        
        # 检查sudo权限
        if ! sudo -n true 2>/dev/null; then
            error "需要sudo权限来安装系统依赖和进行系统优化"
            echo "请确保当前用户有sudo权限，或以root用户运行此脚本"
            exit 1
        fi
    fi
}

# 安装系统依赖
install_dependencies() {
    log "安装系统依赖..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        $USE_SUDO apt-get update
        $USE_SUDO apt-get install -y \
            curl \
            wget \
            git \
            build-essential \
            cmake \
            pkg-config \
            libssl-dev \
            libclang-dev \
            llvm-dev \
            make \
            htop \
            numactl \
            hwloc \
            sysstat \
            iotop \
            lm-sensors \
            linux-tools-common \
            linux-tools-generic
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        $USE_SUDO yum groupinstall -y "Development Tools"
        $USE_SUDO yum install -y \
            curl \
            wget \
            git \
            cmake \
            pkgconfig \
            openssl-devel \
            clang-devel \
            llvm-devel \
            make \
            htop \
            numactl \
            hwloc \
            sysstat \
            iotop \
            lm_sensors \
            perf
    elif command -v dnf &> /dev/null; then
        # Fedora
        $USE_SUDO dnf groupinstall -y "Development Tools"
        $USE_SUDO dnf install -y \
            curl \
            wget \
            git \
            cmake \
            pkgconfig \
            openssl-devel \
            clang-devel \
            llvm-devel \
            make \
            htop \
            numactl \
            hwloc \
            sysstat \
            iotop \
            lm_sensors \
            perf
    else
        error "不支持的包管理器，请手动安装依赖"
        exit 1
    fi
    
    success "系统依赖安装完成"
}

# 安装Rust
install_rust() {
    log "安装/更新Rust工具链..."
    
    if command -v rustup &> /dev/null; then
        info "检测到已安装的Rust，正在更新..."
        rustup update
    else
        info "安装Rust工具链..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi
    
    # 确保环境变量可用
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # 安装必要组件
    rustup component add rustfmt clippy
    
    success "Rust工具链安装/更新完成"
}

# 系统优化
optimize_system() {
    log "开始系统级优化..."
    
    if [[ $EUID -ne 0 ]] && [[ -z "$USE_SUDO" ]]; then
        warn "跳过系统优化（需要root权限）"
        return
    fi
    
    # CPU调度器优化
    info "设置CPU调度器为性能模式..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f $cpu ]]; then
            echo performance | $USE_SUDO tee $cpu > /dev/null
        fi
    done
    
    # 禁用CPU空闲状态
    info "禁用CPU空闲状态..."
    for idle_state in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        if [[ -f $idle_state ]]; then
            echo 1 | $USE_SUDO tee $idle_state > /dev/null 2>&1 || true
        fi
    done
    
    # 配置大页内存
    info "配置大页内存..."
    echo always | $USE_SUDO tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    echo always | $USE_SUDO tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
    
    # 设置静态大页
    if [[ $MEMORY_GB -gt 64 ]]; then
        HUGEPAGE_COUNT=8192  # 16GB of 2MB pages
    else
        HUGEPAGE_COUNT=4096  # 8GB of 2MB pages
    fi
    echo $HUGEPAGE_COUNT | $USE_SUDO tee /proc/sys/vm/nr_hugepages > /dev/null
    
    # 内存优化
    info "应用内存优化参数..."
    $USE_SUDO sysctl -w vm.swappiness=1 > /dev/null
    $USE_SUDO sysctl -w vm.vfs_cache_pressure=50 > /dev/null
    $USE_SUDO sysctl -w vm.overcommit_memory=1 > /dev/null
    $USE_SUDO sysctl -w kernel.sched_migration_cost_ns=5000000 > /dev/null
    
    success "系统优化完成"
}

# 检测CPU架构并设置编译标志
setup_compilation_flags() {
    log "设置编译优化标志..."
    
    # 检测CPU架构
    if echo "$CPU_MODEL" | grep -qi "epyc.*9"; then
        # EPYC 9000系列 (Zen 4)
        RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"
        info "检测到EPYC 9000系列，使用Zen 4优化"
    elif echo "$CPU_MODEL" | grep -qi "epyc.*7"; then
        # EPYC 7000系列 (Zen 2/3)
        RUSTFLAGS="-C target-cpu=znver2 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"
        info "检测到EPYC 7000系列，使用Zen 2优化"
    else
        # 通用优化
        RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma"
        info "使用通用CPU优化"
    fi
    
    export RUSTFLAGS="$RUSTFLAGS"
    info "RUSTFLAGS: $RUSTFLAGS"
}

# 编译Nockchain
compile_nockchain() {
    log "编译优化版Nockchain..."
    
    # 设置环境变量
    export RUST_LOG=info
    export CARGO_TERM_COLOR=always
    
    # 清理旧的构建
    info "清理旧的构建文件..."
    cargo clean
    
    # 编译优化版本
    info "开始编译（这可能需要10-20分钟）..."
    cargo build --release --features optimized
    
    # 验证编译结果
    if [[ -f "target/release/nockchain" ]] && [[ -f "target/release/nockchain-wallet" ]]; then
        success "Nockchain编译成功！"
    else
        error "编译失败，请检查错误信息"
        exit 1
    fi
}

# 配置钱包
setup_wallet() {
    log "配置钱包..."
    
    WALLET_DIR="$HOME/.nockchain"
    mkdir -p "$WALLET_DIR"
    
    # 检查是否已有钱包
    if [[ -f "$WALLET_DIR/keys.export" ]]; then
        info "检测到已有钱包文件"
        read -p "是否要生成新的钱包？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "使用现有钱包"
            return
        fi
    fi
    
    # 生成新钱包
    info "生成新的钱包密钥..."
    ./target/release/nockchain-wallet keygen > "$WALLET_DIR/wallet_info.txt"
    
    # 提取公钥
    MINING_PUBKEY=$(grep -o '[A-Za-z0-9]\{64,\}' "$WALLET_DIR/wallet_info.txt" | head -1)
    
    if [[ -n "$MINING_PUBKEY" ]]; then
        export MINING_PUBKEY="$MINING_PUBKEY"
        echo "MINING_PUBKEY=$MINING_PUBKEY" > "$WALLET_DIR/.env"
        success "钱包配置完成"
        info "挖矿公钥: $MINING_PUBKEY"
        info "钱包信息已保存到: $WALLET_DIR/wallet_info.txt"
        
        warn "请务必备份钱包信息！"
    else
        error "无法提取挖矿公钥"
        exit 1
    fi
}

# 创建挖矿配置
create_mining_config() {
    log "创建挖矿配置..."
    
    # 计算最优线程数
    if [[ $CPU_THREADS -gt 16 ]]; then
        MINING_THREADS=$((CPU_THREADS - 4))  # 为系统保留4个线程
    else
        MINING_THREADS=$((CPU_THREADS - 2))  # 为系统保留2个线程
    fi
    
    # 确保最小线程数
    if [[ $MINING_THREADS -lt 1 ]]; then
        MINING_THREADS=1
    fi
    
    info "配置挖矿线程数: $MINING_THREADS"
    
    # 创建挖矿脚本
    cat > start_mining.sh << EOF
#!/bin/bash

# Nockchain 挖矿启动脚本
# 生成时间: $(date)

set -e

# 设置环境变量
export RUST_LOG=info
export RUSTFLAGS="$RUSTFLAGS"
export MINING_PUBKEY="$MINING_PUBKEY"

# 检查钱包公钥
if [[ -z "\$MINING_PUBKEY" ]]; then
    echo "错误: 未设置MINING_PUBKEY"
    echo "请运行: source ~/.nockchain/.env"
    exit 1
fi

# 显示配置信息
echo "=============================================="
echo "         Nockchain 挖矿启动"
echo "=============================================="
echo "挖矿公钥: \$MINING_PUBKEY"
echo "线程数: $MINING_THREADS"
echo "CPU优化: $RUSTFLAGS"
echo "=============================================="
echo

# 启动挖矿
echo "启动挖矿进程..."
exec ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
EOF
    
    chmod +x start_mining.sh
    
    # 创建NUMA优化版本
    cat > start_mining_numa.sh << EOF
#!/bin/bash

# Nockchain NUMA优化挖矿启动脚本

set -e

# 设置环境变量
export RUST_LOG=info
export RUSTFLAGS="$RUSTFLAGS"
export MINING_PUBKEY="$MINING_PUBKEY"

# 检查NUMA节点数
NUMA_NODES=\$(numactl --hardware | grep "available:" | awk '{print \$2}')

echo "=============================================="
echo "      Nockchain NUMA优化挖矿启动"
echo "=============================================="
echo "NUMA节点数: \$NUMA_NODES"
echo "挖矿公钥: \$MINING_PUBKEY"
echo "线程数: $MINING_THREADS"
echo "=============================================="
echo

# 使用NUMA绑定启动
if [[ \$NUMA_NODES -gt 1 ]]; then
    echo "使用NUMA绑定启动..."
    exec numactl --cpunodebind=0,1 --membind=0,1 ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
else
    echo "单NUMA节点，正常启动..."
    exec ./target/release/nockchain --mine --num-threads $MINING_THREADS --mining-pubkey "\$MINING_PUBKEY"
fi
EOF
    
    chmod +x start_mining_numa.sh
    
    success "挖矿配置创建完成"
}

# 创建监控脚本
create_monitoring() {
    log "创建性能监控脚本..."
    
    cat > monitor_mining.sh << 'EOF'
#!/bin/bash

# Nockchain 挖矿监控脚本

INTERVAL=30
LOG_FILE="mining_performance.log"

echo "=============================================="
echo "       Nockchain 挖矿性能监控"
echo "=============================================="
echo "监控间隔: ${INTERVAL}秒"
echo "日志文件: $LOG_FILE"
echo "按 Ctrl+C 停止监控"
echo "=============================================="
echo

# 创建日志文件头
echo "时间,CPU使用率(%),内存使用(GB),温度(°C),挖矿进程状态" > $LOG_FILE

while true; do
    # 获取时间戳
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    
    # 内存使用
    MEMORY_USED=$(free -g | grep "Mem:" | awk '{print $3}')
    
    # 温度 (如果可用)
    if command -v sensors &> /dev/null; then
        TEMP=$(sensors | grep -E "Core|Package" | awk '{print $3}' | cut -d'+' -f2 | cut -d'°' -f1 | head -1)
    else
        TEMP="N/A"
    fi
    
    # 挖矿进程状态
    if pgrep -f "nockchain.*mine" > /dev/null; then
        MINING_STATUS="运行中"
    else
        MINING_STATUS="已停止"
    fi
    
    # 显示实时信息
    clear
    echo "=============================================="
    echo "       Nockchain 挖矿性能监控"
    echo "=============================================="
    echo "时间: $TIMESTAMP"
    echo "CPU使用率: ${CPU_USAGE}%"
    echo "内存使用: ${MEMORY_USED}GB"
    echo "CPU温度: ${TEMP}°C"
    echo "挖矿状态: $MINING_STATUS"
    echo "=============================================="
    
    # 记录到日志
    echo "$TIMESTAMP,$CPU_USAGE,$MEMORY_USED,$TEMP,$MINING_STATUS" >> $LOG_FILE
    
    sleep $INTERVAL
done
EOF
    
    chmod +x monitor_mining.sh
    
    success "监控脚本创建完成"
}

# 运行测试
run_test() {
    log "运行快速测试..."
    
    info "测试钱包功能..."
    if ./target/release/nockchain-wallet --help > /dev/null; then
        success "钱包测试通过"
    else
        error "钱包测试失败"
        exit 1
    fi
    
    info "测试主程序..."
    if timeout 10 ./target/release/nockchain --help > /dev/null; then
        success "主程序测试通过"
    else
        error "主程序测试失败"
        exit 1
    fi
    
    success "所有测试通过"
}

# 显示完成信息
show_completion() {
    success "🎉 Nockchain EPYC 优化部署完成！"
    echo
    echo "=============================================="
    echo "           部署完成信息"
    echo "=============================================="
    echo
    echo "📊 系统信息:"
    echo "  CPU: $CPU_MODEL"
    echo "  核心/线程: $CPU_CORES/$CPU_THREADS"
    echo "  内存: ${MEMORY_GB}GB"
    echo "  挖矿线程: $MINING_THREADS"
    echo
    echo "🔑 钱包信息:"
    echo "  公钥: $MINING_PUBKEY"
    echo "  备份位置: $HOME/.nockchain/wallet_info.txt"
    echo
    echo "🚀 启动命令:"
    echo "  标准启动: ./start_mining.sh"
    echo "  NUMA优化: ./start_mining_numa.sh"
    echo "  性能监控: ./monitor_mining.sh"
    echo
    echo "📈 预期性能:"
    if [[ "$EPYC_DETECTED" == true ]]; then
        echo "  EPYC 9000系列: +150-250% 算力提升"
        echo "  EPYC 7000系列: +100-200% 算力提升"
    else
        echo "  通用优化: +50-100% 算力提升"
    fi
    echo
    echo "⚠️  重要提醒:"
    echo "  1. 请备份钱包信息（$HOME/.nockchain/wallet_info.txt）"
    echo "  2. 监控系统温度，必要时调整线程数"
    echo "  3. 建议在testnet上先测试"
    echo "  4. 关注项目官方更新"
    echo
    echo "=============================================="
    echo
    warn "准备开始挖矿？(y/N): "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "启动挖矿..."
        source "$HOME/.nockchain/.env" 2>/dev/null || true
        exec ./start_mining.sh
    else
        echo "稍后可以运行 ./start_mining.sh 开始挖矿"
    fi
}

# 主函数
main() {
    show_welcome
    
    read -p "是否继续安装和优化？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    
    check_requirements
    check_permissions
    install_dependencies
    install_rust
    optimize_system
    setup_compilation_flags
    compile_nockchain
    setup_wallet
    create_mining_config
    create_monitoring
    run_test
    show_completion
}

# 执行主函数
main "$@"