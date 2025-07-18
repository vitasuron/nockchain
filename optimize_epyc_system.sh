#!/bin/bash

# Nockchain EPYC 服务器优化脚本
# 用于优化 AMD EPYC 服务器的挖矿性能
# 作者: Nockchain 优化团队
# 使用方法: sudo ./optimize_epyc_system.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要以root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测CPU型号
detect_cpu() {
    log "检测CPU型号..."
    CPU_MODEL=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    
    info "CPU型号: $CPU_MODEL"
    info "CPU核心数: $CPU_CORES"
    info "CPU线程数: $CPU_THREADS"
    
    # 检测是否为EPYC处理器
    if echo "$CPU_MODEL" | grep -qi "epyc"; then
        log "检测到AMD EPYC处理器，继续优化..."
        EPYC_DETECTED=true
    else
        warn "未检测到EPYC处理器，某些优化可能不适用"
        EPYC_DETECTED=false
    fi
}

# 检测NUMA配置
detect_numa() {
    log "检测NUMA配置..."
    NUMA_NODES=$(numactl --hardware | grep "available:" | awk '{print $2}')
    info "NUMA节点数: $NUMA_NODES"
    
    for ((i=0; i<NUMA_NODES; i++)); do
        NODE_CPUS=$(numactl --hardware | grep "node $i cpus:" | cut -d: -f2 | tr -d ' ')
        NODE_MEMORY=$(numactl --hardware | grep "node $i size:" | awk '{print $4 $5}')
        info "NUMA节点 $i: CPUs=$NODE_CPUS, 内存=$NODE_MEMORY"
    done
}

# 设置CPU调度器为性能模式
optimize_cpu_governor() {
    log "设置CPU调度器为性能模式..."
    
    # 备份当前设置
    mkdir -p /tmp/nockchain_backup
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f $cpu ]]; then
            cat $cpu >> /tmp/nockchain_backup/scaling_governor.backup
            break
        fi
    done
    
    # 设置性能模式
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f $cpu ]]; then
            echo performance > $cpu
        fi
    done
    
    # 验证设置
    CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_GOVERNOR" == "performance" ]]; then
        log "CPU调度器已设置为性能模式"
    else
        warn "无法设置CPU调度器为性能模式，当前模式: $CURRENT_GOVERNOR"
    fi
}

# 禁用CPU空闲状态
disable_cpu_idle() {
    log "禁用CPU空闲状态以最大化性能..."
    
    # 备份当前设置
    find /sys/devices/system/cpu/cpu*/cpuidle/state*/disable -exec sh -c 'echo $(cat {}) >> /tmp/nockchain_backup/cpuidle.backup' \;
    
    # 禁用所有空闲状态
    for idle_state in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        if [[ -f $idle_state ]]; then
            echo 1 > $idle_state 2>/dev/null || true
        fi
    done
    
    log "CPU空闲状态已禁用"
}

# 配置透明大页
configure_hugepages() {
    log "配置透明大页..."
    
    # 启用透明大页
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo always > /sys/kernel/mm/transparent_hugepage/defrag
    
    # 配置静态大页（1GB页面，如果支持的话）
    if grep -q pdpe1gb /proc/cpuinfo; then
        info "检测到1GB大页支持"
        HUGEPAGE_SIZE=1048576  # 1GB in KB
        HUGEPAGE_COUNT=64      # 64GB of hugepages
    else
        info "使用2MB大页"
        HUGEPAGE_SIZE=2048     # 2MB in KB
        HUGEPAGE_COUNT=16384   # 32GB of hugepages
    fi
    
    echo $HUGEPAGE_COUNT > /proc/sys/vm/nr_hugepages
    
    # 验证大页配置
    ACTUAL_HUGEPAGES=$(cat /proc/sys/vm/nr_hugepages)
    info "配置大页数量: $HUGEPAGE_COUNT, 实际: $ACTUAL_HUGEPAGES"
}

# 优化内存设置
optimize_memory() {
    log "优化内存设置..."
    
    # 备份当前设置
    sysctl -a | grep -E "(vm\.|kernel\.)" > /tmp/nockchain_backup/sysctl.backup
    
    # 内存优化设置
    cat >> /etc/sysctl.conf << 'EOF'

# Nockchain 挖矿优化设置
# 减少内存交换
vm.swappiness=1
vm.vfs_cache_pressure=50

# 优化内存分配
vm.overcommit_memory=1
vm.max_map_count=262144

# 减少内存碎片
vm.min_free_kbytes=65536

# 网络优化
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.netdev_max_backlog=5000
net.ipv4.tcp_congestion_control=bbr

# 进程优化
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
EOF

    # 应用设置
    sysctl -p
    
    log "内存优化设置已应用"
}

# 配置网络中断亲和性
optimize_irq_affinity() {
    log "优化网络中断亲和性..."
    
    # 查找网络设备的IRQ
    for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|enp)'); do
        if [[ -d "/sys/class/net/$iface/device" ]]; then
            info "优化网络接口 $iface 的中断亲和性..."
            
            # 获取网络设备的IRQ
            IRQ_NUMS=$(grep $iface /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')
            
            for irq in $IRQ_NUMS; do
                if [[ -f "/proc/irq/$irq/smp_affinity" ]]; then
                    # 将网络中断绑定到第一个NUMA节点的第一个CPU
                    echo 1 > /proc/irq/$irq/smp_affinity
                    info "IRQ $irq 已绑定到CPU 0"
                fi
            done
        fi
    done
}

# 设置进程调度优先级
optimize_process_priority() {
    log "设置挖矿进程调度优先级..."
    
    # 创建systemd配置文件
    cat > /etc/systemd/system/nockchain-mining.service << 'EOF'
[Unit]
Description=Nockchain Mining Service
After=network.target

[Service]
Type=simple
User=mining
Group=mining
WorkingDirectory=/opt/nockchain
Environment=RUST_LOG=info
Environment=RUST_BACKTRACE=1
ExecStart=/opt/nockchain/target/release/nockchain --mine
Restart=always
RestartSec=5

# 性能优化设置
Nice=-10
IOSchedulingClass=1
IOSchedulingPriority=2
CPUSchedulingPolicy=2
CPUSchedulingPriority=50

# 内存设置
MemoryHigh=80%
MemoryMax=90%

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/nockchain

[Install]
WantedBy=multi-user.target
EOF

    # 创建挖矿用户
    if ! id "mining" &>/dev/null; then
        useradd -r -s /bin/false -d /opt/nockchain mining
        log "创建挖矿用户 'mining'"
    fi
    
    systemctl daemon-reload
    log "Systemd服务配置已创建"
}

# 安装必要的依赖
install_dependencies() {
    log "安装必要的依赖..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y \
            curl \
            build-essential \
            cmake \
            pkg-config \
            libssl-dev \
            libclang-dev \
            llvm-dev \
            make \
            git \
            htop \
            numactl \
            hwloc \
            sysstat \
            iotop \
            linux-tools-common \
            linux-tools-generic
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum groupinstall -y "Development Tools"
        yum install -y \
            curl \
            cmake \
            pkgconfig \
            openssl-devel \
            clang-devel \
            llvm-devel \
            make \
            git \
            htop \
            numactl \
            hwloc \
            sysstat \
            iotop \
            perf
    else
        warn "未识别的包管理器，请手动安装依赖"
    fi
}

# 安装Rust工具链
install_rust() {
    log "安装/更新Rust工具链..."
    
    # 安装rustup（如果不存在）
    if ! command -v rustup &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    # 更新到最新版本
    rustup update
    rustup default stable
    
    # 安装必要的组件
    rustup component add rustfmt clippy
    
    # 为EPYC优化设置环境变量
    RUSTFLAGS_FILE="/etc/environment"
    
    # 检测CPU架构并设置相应的RUSTFLAGS
    if echo "$CPU_MODEL" | grep -qi "epyc.*9"; then
        # EPYC 9000系列 (Zen 4)
        RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"
    elif echo "$CPU_MODEL" | grep -qi "epyc.*7"; then
        # EPYC 7000系列 (Zen 2/3)
        RUSTFLAGS="-C target-cpu=znver2 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"
    else
        # 通用优化
        RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma"
    fi
    
    # 写入环境变量
    grep -v "RUSTFLAGS" $RUSTFLAGS_FILE > /tmp/environment.new || true
    echo "RUSTFLAGS=\"$RUSTFLAGS\"" >> /tmp/environment.new
    mv /tmp/environment.new $RUSTFLAGS_FILE
    
    log "Rust工具链安装完成，RUSTFLAGS已设置为: $RUSTFLAGS"
}

# 创建性能监控脚本
create_monitoring_script() {
    log "创建性能监控脚本..."
    
    cat > /usr/local/bin/nockchain-monitor.sh << 'EOF'
#!/bin/bash

# Nockchain 挖矿性能监控脚本

LOGFILE="/var/log/nockchain-monitor.log"
INTERVAL=30

log_metric() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOGFILE
}

while true; do
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    
    # 内存使用情况
    MEMORY_INFO=$(free -h | grep "Mem:")
    MEMORY_USED=$(echo $MEMORY_INFO | awk '{print $3}')
    MEMORY_TOTAL=$(echo $MEMORY_INFO | awk '{print $2}')
    
    # 温度信息（如果可用）
    TEMP_INFO=""
    if command -v sensors &> /dev/null; then
        TEMP_INFO=$(sensors | grep -E "Core|Package" | head -5)
    fi
    
    # 挖矿进程信息
    MINING_PROC=$(ps aux | grep nockchain | grep -v grep | head -1)
    
    # 网络统计
    NETWORK_INFO=$(cat /proc/net/dev | grep -E "(eth|ens|enp)" | head -1)
    
    # 记录指标
    log_metric "CPU: ${CPU_USAGE}%, Memory: ${MEMORY_USED}/${MEMORY_TOTAL}"
    [[ -n "$TEMP_INFO" ]] && log_metric "Temperature: $TEMP_INFO"
    [[ -n "$MINING_PROC" ]] && log_metric "Mining Process: $(echo $MINING_PROC | awk '{print $3, $4, $11}')"
    
    sleep $INTERVAL
done
EOF

    chmod +x /usr/local/bin/nockchain-monitor.sh
    
    # 创建systemd服务
    cat > /etc/systemd/system/nockchain-monitor.service << 'EOF'
[Unit]
Description=Nockchain Mining Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nockchain-monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nockchain-monitor.service
    
    log "性能监控脚本已创建并启用"
}

# 创建备份恢复脚本
create_restore_script() {
    log "创建备份恢复脚本..."
    
    cat > /usr/local/bin/restore-nockchain-settings.sh << 'EOF'
#!/bin/bash

# Nockchain 设置恢复脚本

BACKUP_DIR="/tmp/nockchain_backup"

echo "恢复系统设置到优化前状态..."

# 恢复CPU调度器
if [[ -f "$BACKUP_DIR/scaling_governor.backup" ]]; then
    ORIGINAL_GOVERNOR=$(head -1 "$BACKUP_DIR/scaling_governor.backup")
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f $cpu ]]; then
            echo $ORIGINAL_GOVERNOR > $cpu
        fi
    done
    echo "CPU调度器已恢复"
fi

# 恢复CPU空闲状态
if [[ -f "$BACKUP_DIR/cpuidle.backup" ]]; then
    # 重新启用CPU空闲状态
    for idle_state in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        if [[ -f $idle_state ]]; then
            echo 0 > $idle_state 2>/dev/null || true
        fi
    done
    echo "CPU空闲状态已恢复"
fi

# 恢复sysctl设置
if [[ -f "$BACKUP_DIR/sysctl.backup" ]]; then
    # 移除Nockchain相关设置
    sed -i '/# Nockchain 挖矿优化设置/,$d' /etc/sysctl.conf
    sysctl -p
    echo "系统参数已恢复"
fi

# 停止并禁用服务
systemctl stop nockchain-mining.service 2>/dev/null || true
systemctl disable nockchain-mining.service 2>/dev/null || true
systemctl stop nockchain-monitor.service 2>/dev/null || true
systemctl disable nockchain-monitor.service 2>/dev/null || true

echo "恢复完成！建议重启系统以确保所有设置生效。"
EOF

    chmod +x /usr/local/bin/restore-nockchain-settings.sh
    log "备份恢复脚本已创建: /usr/local/bin/restore-nockchain-settings.sh"
}

# 显示优化结果
show_optimization_results() {
    log "优化完成！系统配置摘要："
    echo
    info "CPU信息:"
    info "  型号: $CPU_MODEL"
    info "  核心/线程: $CPU_CORES/$CPU_THREADS"
    info "  当前调度器: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    echo
    info "内存信息:"
    free -h
    echo
    info "大页配置:"
    grep -E "(HugePages|Hugepagesize)" /proc/meminfo
    echo
    info "NUMA配置:"
    numactl --hardware | head -5
    echo
    warn "重要提示:"
    warn "1. 建议重启系统以确保所有优化生效"
    warn "2. 使用 /usr/local/bin/restore-nockchain-settings.sh 可恢复原始设置"
    warn "3. 启动挖矿前请确保已正确配置钱包和网络"
    warn "4. 监控日志位置: /var/log/nockchain-monitor.log"
    echo
    log "准备开始挖矿！建议的启动命令:"
    info "export RUSTFLAGS=\"$RUSTFLAGS\""
    info "cargo build --release --features optimized"
    info "sudo systemctl start nockchain-mining.service"
}

# 主函数
main() {
    echo "============================================"
    echo "    Nockchain EPYC 服务器优化脚本"
    echo "============================================"
    echo
    
    check_root
    detect_cpu
    detect_numa
    
    echo
    read -p "是否继续执行优化？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "优化已取消"
        exit 0
    fi
    
    install_dependencies
    install_rust
    optimize_cpu_governor
    disable_cpu_idle
    configure_hugepages
    optimize_memory
    optimize_irq_affinity
    optimize_process_priority
    create_monitoring_script
    create_restore_script
    
    show_optimization_results
}

# 执行主函数
main "$@"