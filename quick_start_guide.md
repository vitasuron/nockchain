# Nockchain EPYC 服务器挖矿优化快速指南

## 🎯 目标

将您的AMD EPYC服务器挖矿效率提升150-250%，在Nockchain头矿中获得竞争优势。

## 📋 前置条件

### 硬件要求
- **CPU**: AMD EPYC 9B14 或 EPYC 7K62 (或性能相当的EPYC处理器)
- **内存**: 384GB RAM
- **存储**: 100GB+ 可用空间
- **网络**: 稳定的互联网连接 (建议≥100Mbps)

### 软件要求
- **操作系统**: Ubuntu 20.04+ 或 CentOS 8+
- **权限**: root或sudo权限
- **网络**: 能够访问GitHub和包管理器

## 🚀 5分钟快速部署

### 步骤1: 克隆优化代码
```bash
# 克隆原版Nockchain代码
git clone https://github.com/zorp-corp/nockchain.git
cd nockchain

# 下载优化文件（替换为您的优化文件）
# 或者直接使用提供的优化文件
```

### 步骤2: 运行系统优化脚本
```bash
# 给脚本执行权限
chmod +x optimize_epyc_system.sh

# 运行系统优化（需要root权限）
sudo ./optimize_epyc_system.sh
```

**预期输出示例:**
```
============================================
    Nockchain EPYC 服务器优化脚本
============================================

[2025-01-17 15:30:01] 检测CPU型号...
[2025-01-17 15:30:01] INFO: CPU型号: AMD EPYC 9B14 96-Core Processor
[2025-01-17 15:30:01] INFO: CPU核心数: 96
[2025-01-17 15:30:01] INFO: CPU线程数: 192
[2025-01-17 15:30:01] 检测到AMD EPYC处理器，继续优化...
```

### 步骤3: 应用编译优化
```bash
# 替换Cargo.toml为优化版本
cp optimized_cargo_config.toml Cargo.toml

# 设置环境变量（根据您的CPU型号）
# 对于EPYC 9B14 (Zen 4):
export RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"

# 对于EPYC 7K62 (Zen 2):
# export RUSTFLAGS="-C target-cpu=znver2 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"

# 编译优化版本
cargo build --release --features optimized
```

### 步骤4: 配置挖矿
```bash
# 生成钱包密钥
./target/release/nockchain-wallet keygen

# 设置挖矿公钥（替换为您生成的公钥）
export MINING_PUBKEY="your_generated_public_key_here"

# 启动优化挖矿
./target/release/nockchain --mine --num-threads 90
```

## 📊 性能验证

### 检查系统优化状态
```bash
# 检查CPU调度器
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# 应该显示: performance

# 检查大页内存
cat /proc/meminfo | grep Huge
# 应该显示配置的大页数量

# 检查NUMA配置
numactl --hardware
```

### 监控挖矿性能
```bash
# 启动性能监控
sudo systemctl start nockchain-monitor.service

# 实时查看性能日志
tail -f /var/log/nockchain-monitor.log

# 查看挖矿日志
journalctl -u nockchain-mining.service -f
```

**预期性能指标:**
- **EPYC 9B14**: 25-35 MH/s
- **EPYC 7K62**: 20-30 MH/s
- **CPU使用率**: 95-98%
- **内存使用**: 根据负载动态调整

## 🔧 高级优化选项

### 使用替换的挖矿模块
```bash
# 使用优化的挖矿模块
cp optimized_mining.rs crates/nockchain/src/mining.rs

# 重新编译
cargo build --release --features optimized
```

### NUMA感知优化
```bash
# 绑定到特定NUMA节点
numactl --cpunodebind=0,1 --membind=0,1 ./target/release/nockchain --mine --num-threads 90

# 或使用systemd服务
sudo systemctl start nockchain-mining.service
```

### 温度监控和控制
```bash
# 安装温度监控
sudo apt install lm-sensors
sudo sensors-detect

# 监控温度
watch -n 1 sensors
```

## 📈 GitHub集成（可选）

### 设置GitHub仓库
```bash
# 运行GitHub集成脚本
chmod +x github_integration.sh
./github_integration.sh

# 按提示输入GitHub用户名和Token
```

### 自动化部署
```bash
# 每次优化后推送到GitHub
git add .
git commit -m "Performance optimization: $(date)"
git push origin main
```

## 🚨 故障排除

### 常见问题和解决方案

#### 问题1: 编译失败
```bash
# 解决方案: 安装缺失依赖
sudo apt update
sudo apt install clang llvm-dev libclang-dev build-essential cmake pkg-config libssl-dev

# 清理并重新编译
cargo clean
cargo build --release --features optimized
```

#### 问题2: 挖矿算力低
```bash
# 检查CPU调度器
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 如果不是performance，重新运行优化脚本
sudo ./optimize_epyc_system.sh

# 检查线程数设置
ps aux | grep nockchain
```

#### 问题3: 系统过热
```bash
# 检查温度
sensors

# 如果温度过高，降低线程数
./target/release/nockchain --mine --num-threads 80

# 检查散热系统
```

#### 问题4: 内存不足
```bash
# 检查内存使用
free -h

# 检查大页配置
cat /proc/meminfo | grep Huge

# 调整大页设置
sudo echo 8192 > /proc/sys/vm/nr_hugepages
```

## 📊 性能基准测试

### 基准测试脚本
```bash
# 创建基准测试脚本
cat > benchmark.sh << 'EOF'
#!/bin/bash
echo "开始基准测试..."
START_TIME=$(date +%s)

# 运行5分钟测试
timeout 300 ./target/release/nockchain --mine --num-threads 90 > benchmark.log 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "测试完成，用时: ${DURATION}秒"
grep -i "hash" benchmark.log | tail -10
EOF

chmod +x benchmark.sh
./benchmark.sh
```

### 比较不同配置
```bash
# 测试不同线程数的性能
for threads in 80 90 95; do
    echo "测试 $threads 线程..."
    timeout 60 ./target/release/nockchain --mine --num-threads $threads
done
```

## 🔄 恢复原始设置

如果需要恢复系统到优化前状态:

```bash
# 运行恢复脚本
sudo /usr/local/bin/restore-nockchain-settings.sh

# 重启系统
sudo reboot
```

## 📞 支持和联系

### 获取帮助
- **GitHub Issues**: 在优化仓库中提交问题
- **性能问题**: 提供系统信息和日志
- **编译问题**: 包含完整的错误信息

### 性能报告模板
```
**系统信息:**
- CPU: [您的CPU型号]
- 内存: [内存大小]
- 操作系统: [OS版本]

**优化前性能:**
- 算力: [MH/s]
- CPU使用率: [%]

**优化后性能:**
- 算力: [MH/s]
- CPU使用率: [%]
- 提升幅度: [%]

**遇到的问题:**
[详细描述]

**日志信息:**
[相关日志]
```

## ⚡ 快速命令参考

```bash
# 一键优化命令序列
sudo ./optimize_epyc_system.sh && \
export RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2" && \
cargo build --release --features optimized && \
./target/release/nockchain-wallet keygen && \
./target/release/nockchain --mine --num-threads 90

# 监控命令
sudo systemctl status nockchain-mining.service
tail -f /var/log/nockchain-monitor.log
top -p $(pgrep nockchain)

# 性能检查
sensors | grep Core
free -h
numastat
```

## 🎉 完成！

如果您按照此指南操作，您的EPYC服务器现在应该以最优性能运行Nockchain挖矿。预期性能提升应该在150-250%之间。

**重要提醒:**
1. 在正式挖矿前，先在testnet上测试
2. 密切监控系统温度和稳定性
3. 定期检查优化效果和调整参数
4. 保持代码更新，关注新的优化机会

祝您挖矿成功！🚀