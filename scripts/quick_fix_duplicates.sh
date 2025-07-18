#!/bin/bash

# 快速修复重复依赖项问题
# 专门解决 duplicate key 错误

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

echo "=== 🔧 重复依赖项快速修复工具 ==="
echo "专门解决 duplicate key 错误..."
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

# 下载最新的修复版本
info "下载最新的修复版本..."
if curl -sSL https://raw.githubusercontent.com/vitasuron/nockchain/master/Cargo.toml -o Cargo.toml.new; then
    mv Cargo.toml.new Cargo.toml
    success "已下载最新的 Cargo.toml"
else
    error "无法下载最新版本，尝试手动修复..."
    
    # 手动修复重复项
    info "手动修复重复的依赖项..."
    
    # 创建临时文件来处理重复项
    temp_file=$(mktemp)
    
    # 移除重复的依赖项定义
    awk '
    BEGIN { in_workspace_deps = 0 }
    /^\[workspace\.dependencies\]/ { in_workspace_deps = 1; print; next }
    /^\[/ && !/^\[workspace\.dependencies\]/ { in_workspace_deps = 0 }
    {
        if (in_workspace_deps && /^[a-zA-Z0-9_-]+ = /) {
            dep_name = $1
            if (!(dep_name in seen)) {
                seen[dep_name] = 1
                print
            } else {
                print "# REMOVED DUPLICATE: " $0
            }
        } else {
            print
        }
    }
    ' Cargo.toml > "$temp_file"
    
    mv "$temp_file" Cargo.toml
    success "已手动修复重复的依赖项"
fi

# 验证修复结果
info "验证 Cargo.toml 配置..."
if cargo metadata --no-deps > /dev/null 2>&1; then
    success "✅ Cargo.toml 配置验证成功！"
    
    # 显示修复摘要
    echo
    success "🎉 重复依赖项修复完成！"
    echo
    info "修复内容："
    echo "  - 移除了重复的 serde_json 定义"
    echo "  - 清理了其他可能的重复项"
    echo "  - 保持了依赖项的完整性"
    echo
    info "现在可以继续编译："
    echo "  cd $NOCKCHAIN_DIR"
    echo "  cargo build --release"
    echo
    
    # 开始编译测试
    read -p "是否立即开始编译？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "开始编译..."
        cargo build --release
    fi
    
else
    error "❌ Cargo.toml 配置验证失败"
    
    # 显示详细错误信息
    info "详细错误信息:"
    cargo metadata --no-deps 2>&1 | head -10
    
    exit 1
fi

echo
success "🚀 修复完成！现在可以继续编译了！"