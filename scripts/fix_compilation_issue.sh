#!/bin/bash

# Quick fix for the duplicate criterion key issue in Cargo.toml
# This script can be run to fix the issue and resume compilation

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

NOCKCHAIN_DIR="${NOCKCHAIN_DIR:-/opt/nockchain}"

echo "=== Nockchain 编译修复工具 ==="
echo "正在修复 Cargo.toml 中的重复 criterion 键问题..."
echo

# 检查项目目录
if [[ ! -d "$NOCKCHAIN_DIR" ]]; then
    error "Nockchain 目录不存在: $NOCKCHAIN_DIR"
    exit 1
fi

cd "$NOCKCHAIN_DIR"

# 检查 Cargo.toml 是否存在
if [[ ! -f "Cargo.toml" ]]; then
    error "Cargo.toml 文件不存在"
    exit 1
fi

# 检查是否存在重复的 criterion 键
CRITERION_COUNT=$(grep -c "^criterion = " Cargo.toml || echo "0")

if [[ $CRITERION_COUNT -gt 1 ]]; then
    info "检测到重复的 criterion 键，正在修复..."
    
    # 备份原文件
    cp Cargo.toml Cargo.toml.backup
    success "已备份原文件为 Cargo.toml.backup"
    
    # 下载修复后的 Cargo.toml
    info "下载修复后的 Cargo.toml..."
    curl -sSL https://raw.githubusercontent.com/vitasuron/nockchain/master/Cargo.toml -o Cargo.toml.new
    
    if [[ -f "Cargo.toml.new" ]]; then
        mv Cargo.toml.new Cargo.toml
        success "Cargo.toml 已修复"
    else
        error "无法下载修复后的文件，手动修复..."
        
        # 手动移除重复的 criterion 条目
        # 保留第一个 criterion 条目，移除后续的
        sed -i '/^criterion = { git = "https:\/\/github\.com\/vlovich\/criterion\.rs\.git"/d' Cargo.toml
        
        success "已手动移除重复的 criterion 条目"
    fi
else
    success "未检测到重复的 criterion 键，文件已经是正确的"
fi

# 验证修复结果
NEW_CRITERION_COUNT=$(grep -c "^criterion = " Cargo.toml || echo "0")
info "修复后的 criterion 条目数量: $NEW_CRITERION_COUNT"

if [[ $NEW_CRITERION_COUNT -eq 1 ]]; then
    success "Cargo.toml 修复成功！"
    echo
    info "现在可以继续编译了..."
    
    # 设置环境变量
    export PATH="/root/.cargo/bin:$PATH"
    
    # 检测CPU架构
    if grep -q "EPYC 9" /proc/cpuinfo 2>/dev/null; then
        EPYC_ARCH="znver4"
        info "检测到 EPYC 9000 系列，使用 Zen 4 优化"
    elif grep -q "EPYC 7" /proc/cpuinfo 2>/dev/null; then
        EPYC_ARCH="znver2"
        info "检测到 EPYC 7000 系列，使用 Zen 2 优化"
    else
        EPYC_ARCH="znver3"
        warn "未检测到特定EPYC型号，使用通用 Zen 3 优化"
    fi
    
    # 设置编译标志
    export RUSTFLAGS="-C target-cpu=$EPYC_ARCH -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul -C link-arg=-fuse-ld=lld"
    export CARGO_BUILD_JOBS="$(nproc)"
    
    echo "编译标志设置完成:"
    echo "  - RUSTFLAGS: $RUSTFLAGS"
    echo "  - CARGO_BUILD_JOBS: $CARGO_BUILD_JOBS"
    echo
    
    # 询问是否立即开始编译
    read -p "是否立即开始编译？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "开始编译 Nockchain..."
        cargo clean
        
        if cargo build --release; then
            success "编译成功完成！"
            echo
            info "可执行文件位置: $(pwd)/target/release/"
            ls -la target/release/nockchain* 2>/dev/null || true
        else
            warn "编译失败，尝试不使用默认特性..."
            if cargo build --release --no-default-features; then
                success "编译成功完成！(无默认特性)"
            else
                error "编译仍然失败，请检查编译错误信息"
                exit 1
            fi
        fi
    else
        info "修复完成，可以手动运行编译命令："
        echo "  cd $NOCKCHAIN_DIR"
        echo "  cargo build --release"
    fi
    
elif [[ $NEW_CRITERION_COUNT -eq 0 ]]; then
    error "修复后没有 criterion 条目，这可能导致其他问题"
    exit 1
else
    error "修复后仍有多个 criterion 条目，需要手动检查"
    exit 1
fi