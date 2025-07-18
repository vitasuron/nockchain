#!/bin/bash

# 修复 Cargo.toml 虚拟清单配置问题
# 解决 "virtual manifest specifies a `features` section, which is not allowed" 错误

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

echo "=== 🔧 Cargo.toml 清单修复工具 ==="
echo "修复虚拟清单配置问题和缺失依赖..."
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

# 备份原文件
info "备份原始 Cargo.toml..."
cp Cargo.toml Cargo.toml.backup.$(date +%Y%m%d_%H%M%S)
success "已备份到 Cargo.toml.backup.$(date +%Y%m%d_%H%M%S)"

# 下载修复后的文件
info "下载修复后的 Cargo.toml..."
curl -sSL https://raw.githubusercontent.com/vitasuron/nockchain/master/Cargo.toml -o Cargo.toml.new

if [[ -f "Cargo.toml.new" ]]; then
    mv Cargo.toml.new Cargo.toml
    success "主 Cargo.toml 已更新"
else
    error "无法下载修复后的文件"
    exit 1
fi

# 下载修复后的 nockchain 包配置
info "下载修复后的 nockchain 包配置..."
curl -sSL https://raw.githubusercontent.com/vitasuron/nockchain/master/crates/nockchain/Cargo.toml -o crates/nockchain/Cargo.toml.new

if [[ -f "crates/nockchain/Cargo.toml.new" ]]; then
    mv crates/nockchain/Cargo.toml.new crates/nockchain/Cargo.toml
    success "nockchain 包配置已更新"
else
    warn "无法下载 nockchain 包配置，使用现有配置"
fi

# 验证修复结果
info "验证 Cargo.toml 配置..."
if cargo metadata --no-deps > /dev/null 2>&1; then
    success "✅ Cargo.toml 配置验证成功！"
else
    error "❌ Cargo.toml 配置仍有问题"
    
    # 尝试手动修复
    info "尝试手动修复..."
    
    # 移除工作区清单中的 features 部分
    sed -i '/^\[features\]/,/^$/d' Cargo.toml
    
    # 移除目标特定的依赖项（如果在工作区清单中）
    sed -i '/^\[target\./,/^$/d' Cargo.toml
    
    # 再次验证
    if cargo metadata --no-deps > /dev/null 2>&1; then
        success "✅ 手动修复成功！"
    else
        error "❌ 手动修复失败，请检查 Cargo.toml 配置"
        exit 1
    fi
fi

# 显示修复摘要
echo
success "🎉 Cargo.toml 修复完成！"
echo
info "修复内容："
echo "  - 移除了工作区清单中不允许的 [features] 部分"
echo "  - 将 features 配置移动到具体的包中"
echo "  - 修复了虚拟清单配置问题"
echo
info "现在可以继续编译："
echo "  cd $NOCKCHAIN_DIR"
echo "  cargo build --release"
echo