#!/bin/bash

# EPYC CPU 全速编译优化脚本
# 专门针对AMD EPYC处理器的极致编译性能优化

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
turbo() { echo -e "${PURPLE}[TURBO]${NC} $1"; }

echo "=== 🚀 EPYC 全速编译优化器 ==="
echo "专为AMD EPYC处理器设计的极致编译性能优化"
echo

# 检测CPU信息
detect_cpu_info() {
    info "🔍 检测CPU信息..."
    
    # 获取CPU详细信息
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    CPU_CORES=$(nproc --all)
    CPU_THREADS=$(grep -c ^processor /proc/cpuinfo)
    CPU_FREQ_MAX=$(lscpu | grep "CPU max MHz" | cut -d':' -f2 | xargs | cut -d'.' -f1)
    
    # 检测EPYC型号
    if echo "$CPU_MODEL" | grep -q "EPYC 9"; then
        EPYC_ARCH="znver4"
        EPYC_GEN="Zen 4"
        COMPILE_THREADS=$((CPU_THREADS + 16))  # 超线程优化
    elif echo "$CPU_MODEL" | grep -q "EPYC 7"; then
        EPYC_ARCH="znver2"
        EPYC_GEN="Zen 2"
        COMPILE_THREADS=$((CPU_THREADS + 8))   # 适度超线程
    else
        EPYC_ARCH="znver3"
        EPYC_GEN="Zen 3"
        COMPILE_THREADS=$((CPU_THREADS + 12))  # 通用优化
    fi
    
    # 显示检测结果
    turbo "CPU型号: $CPU_MODEL"
    turbo "架构: $EPYC_GEN ($EPYC_ARCH)"
    turbo "物理核心: $CPU_CORES"
    turbo "逻辑线程: $CPU_THREADS"
    turbo "最大频率: ${CPU_FREQ_MAX:-未知} MHz"
    turbo "编译线程: $COMPILE_THREADS (超线程优化)"
    echo
}

# 设置CPU性能模式
set_cpu_performance() {
    info "⚡ 设置CPU性能模式..."
    
    # 设置CPU调度器为性能模式
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || warn "无法设置CPU调度器"
    
    # 禁用CPU节能模式
    echo 1 | tee /sys/devices/system/cpu/smt/control > /dev/null 2>&1 || warn "无法控制SMT"
    
    # 设置CPU亲和性优化
    echo 0 | tee /proc/sys/kernel/numa_balancing > /dev/null 2>&1 || warn "无法禁用NUMA平衡"
    
    # 设置编译进程优先级
    echo -20 > /proc/sys/kernel/sched_rt_runtime_us 2>/dev/null || warn "无法设置实时调度"
    
    success "CPU性能模式已设置"
}

# 优化内存和IO
optimize_memory_io() {
    info "💾 优化内存和IO性能..."
    
    # 设置内存回收策略
    echo 1 > /proc/sys/vm/swappiness
    echo 1 > /proc/sys/vm/overcommit_memory
    echo 0 > /proc/sys/vm/zone_reclaim_mode
    
    # 优化文件系统缓存
    echo 10 > /proc/sys/vm/vfs_cache_pressure
    echo 262144 > /proc/sys/vm/max_map_count
    
    # 设置IO调度器
    for disk in /sys/block/*/queue/scheduler; do
        if [[ -f "$disk" ]]; then
            echo mq-deadline > "$disk" 2>/dev/null || echo kyber > "$disk" 2>/dev/null || true
        fi
    done
    
    # 禁用透明大页（编译时可能影响性能）
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || warn "无法禁用透明大页"
    
    success "内存和IO优化完成"
}

# 设置编译环境变量
setup_compile_env() {
    info "🔧 设置编译环境变量..."
    
    # 基础编译标志
    export RUSTFLAGS="-C target-cpu=$EPYC_ARCH"
    export RUSTFLAGS="$RUSTFLAGS -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul,+avx512f,+avx512cd,+avx512bw,+avx512dq,+avx512vl"
    export RUSTFLAGS="$RUSTFLAGS -C opt-level=3"
    export RUSTFLAGS="$RUSTFLAGS -C lto=fat"
    export RUSTFLAGS="$RUSTFLAGS -C codegen-units=1"
    export RUSTFLAGS="$RUSTFLAGS -C panic=abort"
    export RUSTFLAGS="$RUSTFLAGS -C link-arg=-fuse-ld=lld"
    
    # 并行编译设置
    export CARGO_BUILD_JOBS="$COMPILE_THREADS"
    export MAKEFLAGS="-j$COMPILE_THREADS"
    export CARGO_BUILD_PIPELINING="true"
    
    # 内存优化
    export CARGO_NET_RETRY=10
    export CARGO_HTTP_TIMEOUT=300
    export CARGO_HTTP_LOW_SPEED_LIMIT=1024
    
    # 链接器优化
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="clang"
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS="$RUSTFLAGS"
    
    # 设置编译缓存
    export CARGO_INCREMENTAL=0  # 禁用增量编译以获得最佳性能
    export RUST_BACKTRACE=0     # 禁用回溯以减少开销
    
    turbo "编译环境变量设置完成:"
    echo "  - 目标架构: $EPYC_ARCH ($EPYC_GEN)"
    echo "  - 编译线程: $COMPILE_THREADS"
    echo "  - 优化级别: O3 + LTO"
    echo "  - 向量化: AVX2 + AVX512"
    echo "  - 链接器: LLD (快速链接)"
    echo
}

# 安装编译依赖
install_compile_deps() {
    info "📦 安装编译依赖..."
    
    # 更新包管理器
    if command -v apt &> /dev/null; then
        apt update -qq
        apt install -y build-essential clang lld llvm-dev pkg-config libssl-dev
    elif command -v yum &> /dev/null; then
        yum install -y gcc gcc-c++ clang lld llvm-devel pkgconfig openssl-devel
    fi
    
    # 安装Rust工具链（如果没有）
    if ! command -v rustc &> /dev/null; then
        info "安装Rust工具链..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source ~/.cargo/env
    fi
    
    # 更新到最新版本
    rustup update
    
    success "编译依赖安装完成"
}

# 执行全速编译
turbo_compile() {
    info "🚀 开始全速编译..."
    
    # 显示编译前系统状态
    turbo "编译前系统状态:"
    echo "  - 可用内存: $(free -h | grep Mem | awk '{print $7}')"
    echo "  - CPU负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  - 磁盘空间: $(df -h . | tail -1 | awk '{print $4}')"
    echo
    
    # 设置编译时的进程优先级
    renice -n -10 $$ 2>/dev/null || warn "无法设置进程优先级"
    
    # 开始编译计时
    COMPILE_START=$(date +%s)
    
    # 清理旧构建
    info "清理旧构建..."
    cargo clean
    
    # 执行编译
    turbo "开始全速编译 (使用 $COMPILE_THREADS 个线程)..."
    
    # 使用taskset绑定CPU核心（如果可用）
    if command -v taskset &> /dev/null; then
        turbo "使用CPU亲和性优化..."
        taskset -c 0-$((CPU_CORES-1)) cargo build --release --verbose
    else
        cargo build --release --verbose
    fi
    
    # 计算编译时间
    COMPILE_END=$(date +%s)
    COMPILE_TIME=$((COMPILE_END - COMPILE_START))
    
    success "编译完成！耗时: ${COMPILE_TIME}秒"
    
    # 显示编译结果
    if [[ -f "target/release/nockchain" ]]; then
        turbo "编译结果:"
        ls -lh target/release/nockchain*
        
        # 显示二进制文件信息
        if command -v file &> /dev/null; then
            echo "  - 文件类型: $(file target/release/nockchain | cut -d':' -f2)"
        fi
        
        # 检查优化标志
        if command -v objdump &> /dev/null; then
            ARCH_INFO=$(objdump -f target/release/nockchain | grep architecture || echo "未知架构")
            echo "  - 架构信息: $ARCH_INFO"
        fi
        
        success "🎉 全速编译成功完成！"
    else
        error "编译失败，未找到可执行文件"
        return 1
    fi
}

# 性能验证
verify_performance() {
    info "📊 验证编译性能..."
    
    # 检查CPU使用情况
    turbo "编译后系统状态:"
    echo "  - 当前CPU使用: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "  - 内存使用: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "  - 平均负载: $(uptime | awk -F'load average:' '{print $2}')"
    
    # 运行简单的性能测试
    if [[ -f "target/release/nockchain" ]]; then
        turbo "运行性能测试..."
        timeout 10s ./target/release/nockchain --help > /dev/null 2>&1 && success "程序运行正常" || warn "程序测试超时"
    fi
}

# 主函数
main() {
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "需要root权限运行此脚本"
        exit 1
    fi
    
    # 检查是否在正确目录
    if [[ ! -f "Cargo.toml" ]]; then
        error "请在Nockchain项目根目录运行此脚本"
        exit 1
    fi
    
    # 执行优化流程
    detect_cpu_info
    set_cpu_performance
    optimize_memory_io
    install_compile_deps
    setup_compile_env
    turbo_compile
    verify_performance
    
    echo
    success "🎉 EPYC全速编译优化完成！"
    turbo "您的EPYC处理器已被充分利用进行编译优化"
    echo
    echo "下一步："
    echo "  cd $(pwd)"
    echo "  ./target/release/nockchain"
    echo
}

# 执行主函数
main "$@"