#!/bin/bash

# Nockchain EPYC 优化验证脚本
# 用于验证优化部署是否成功

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查函数
check_files() {
    info "检查优化文件是否存在..."
    
    local files=(
        "Cargo.toml"
        "scripts/epyc_mining_setup.sh"
        "docs/EPYC_OPTIMIZATION.md"
        "QUICK_START.md"
        "DEPLOYMENT_GUIDE.md"
        "EPYC_OPTIMIZATION_SUMMARY.md"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            success "文件存在: $file"
        else
            error "文件缺失: $file"
            return 1
        fi
    done
}

check_cargo_config() {
    info "检查Cargo配置..."
    
    if grep -q "optimized.*jemalloc.*simd.*numa" Cargo.toml; then
        success "Cargo.toml包含性能优化配置"
    else
        error "Cargo.toml缺少优化配置"
        return 1
    fi
    
    if grep -q "opt-level = 3" Cargo.toml; then
        success "包含最高优化级别配置"
    else
        warning "可能缺少最高优化级别配置"
    fi
}

check_setup_script() {
    info "检查部署脚本..."
    
    if [[ -x "scripts/epyc_mining_setup.sh" ]]; then
        success "部署脚本有执行权限"
    else
        error "部署脚本缺少执行权限"
        return 1
    fi
    
    local required_functions=(
        "detect_cpu_features"
        "optimize_system"
        "compile_nockchain"
        "setup_wallet"
    )
    
    for func in "${required_functions[@]}"; do
        if grep -q "$func" scripts/epyc_mining_setup.sh; then
            success "包含函数: $func"
        else
            warning "可能缺少函数: $func"
        fi
    done
}

check_system_requirements() {
    info "检查系统环境..."
    
    # 检查CPU
    if lscpu | grep -qi "AMD"; then
        if lscpu | grep -qi "EPYC"; then
            success "检测到AMD EPYC处理器"
        else
            warning "AMD处理器但非EPYC系列"
        fi
    else
        warning "非AMD处理器，优化效果可能有限"
    fi
    
    # 检查内存
    local memory_gb=$(free -g | grep "Mem:" | awk '{print $2}')
    if [[ $memory_gb -ge 32 ]]; then
        success "内存充足: ${memory_gb}GB"
    else
        warning "内存可能不足: ${memory_gb}GB (建议32GB+)"
    fi
    
    # 检查必要工具
    local tools=("curl" "wget" "git" "gcc")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            success "工具可用: $tool"
        else
            error "缺少工具: $tool"
        fi
    done
}

check_rust_environment() {
    info "检查Rust环境..."
    
    if command -v rustc &> /dev/null; then
        local rust_version=$(rustc --version)
        success "Rust已安装: $rust_version"
        
        if command -v cargo &> /dev/null; then
            success "Cargo可用"
        else
            error "Cargo不可用"
            return 1
        fi
    else
        warning "Rust未安装，部署脚本会自动安装"
    fi
}

check_build_status() {
    info "检查编译状态..."
    
    if [[ -d "target/release" ]]; then
        if [[ -f "target/release/nockchain" ]]; then
            success "Nockchain主程序已编译"
        else
            warning "Nockchain主程序未编译"
        fi
        
        if [[ -f "target/release/nockchain-wallet" ]]; then
            success "Nockchain钱包已编译"
        else
            warning "Nockchain钱包未编译"
        fi
    else
        info "尚未编译，需要运行部署脚本"
    fi
}

check_generated_scripts() {
    info "检查生成的脚本..."
    
    local scripts=("start_mining.sh" "start_mining_numa.sh" "monitor_mining.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                success "脚本存在且可执行: $script"
            else
                warning "脚本存在但不可执行: $script"
            fi
        else
            info "脚本未生成（部署后创建）: $script"
        fi
    done
}

run_quick_test() {
    info "运行快速测试..."
    
    # 测试Cargo配置
    if cargo check --features optimized &> /dev/null; then
        success "Cargo配置验证通过"
    else
        warning "Cargo配置可能有问题"
    fi
    
    # 检查文档链接
    local docs=("QUICK_START.md" "DEPLOYMENT_GUIDE.md")
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]] && [[ $(wc -l < "$doc") -gt 10 ]]; then
            success "文档完整: $doc"
        else
            warning "文档可能不完整: $doc"
        fi
    done
}

# 主要验证函数
main() {
    echo
    echo "=============================================="
    echo "     🔍 Nockchain EPYC 优化验证"
    echo "=============================================="
    echo
    
    local error_count=0
    
    check_files || ((error_count++))
    echo
    
    check_cargo_config || ((error_count++))
    echo
    
    check_setup_script || ((error_count++))
    echo
    
    check_system_requirements || ((error_count++))
    echo
    
    check_rust_environment || ((error_count++))
    echo
    
    check_build_status || ((error_count++))
    echo
    
    check_generated_scripts || ((error_count++))
    echo
    
    run_quick_test || ((error_count++))
    echo
    
    echo "=============================================="
    if [[ $error_count -eq 0 ]]; then
        success "✨ 验证完成！所有检查通过"
        echo
        info "🚀 可以开始部署："
        echo "   sudo bash scripts/epyc_mining_setup.sh"
    else
        warning "⚠️  发现 $error_count 个问题"
        echo
        info "📋 建议操作："
        echo "   1. 检查缺失的文件和工具"
        echo "   2. 运行部署脚本解决环境问题"
        echo "   3. 重新运行此验证脚本"
    fi
    echo "=============================================="
    echo
}

# 运行验证
main "$@"