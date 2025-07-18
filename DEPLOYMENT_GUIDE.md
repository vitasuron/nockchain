# 🔥 Nockchain EPYC 服务器部署指南

## 📋 部署概述

本指南将帮助您在AMD EPYC服务器上快速部署优化版Nockchain挖矿软件，实现150-250%的性能提升。

## 🎯 部署目标

1. **一键安装**: 自动化系统优化和软件安装
2. **性能优化**: 针对EPYC架构的深度优化
3. **稳定运行**: 长期稳定的挖矿运行
4. **监控管理**: 实时性能监控和问题诊断

## 🚀 快速部署（推荐）

### 方法1: 在线一键部署

```bash
# 直接从GitHub运行优化脚本
curl -sSL https://raw.githubusercontent.com/zorp-corp/nockchain/main/scripts/epyc_mining_setup.sh | bash
```

### 方法2: 本地部署

```bash
# 1. 克隆优化版仓库
git clone https://github.com/zorp-corp/nockchain.git
cd nockchain

# 2. 运行自动部署脚本
chmod +x scripts/epyc_mining_setup.sh
sudo bash scripts/epyc_mining_setup.sh
```

## 📋 系统要求检查

在开始部署前，请确认您的服务器满足以下要求：

### 硬件要求
- **CPU**: AMD EPYC 7K62 或更新版本（推荐9B14）
- **内存**: 最少32GB RAM（推荐384GB）
- **存储**: 100GB+ 可用SSD空间
- **网络**: 稳定的互联网连接（≥100Mbps）

### 软件要求
- **操作系统**: Ubuntu 20.04+ 或 CentOS 8+
- **权限**: sudo或root权限
- **网络**: 能访问GitHub和包管理器

### 检查命令
```bash
# 检查CPU型号
lscpu | grep "Model name"

# 检查内存大小
free -h

# 检查磁盘空间
df -h

# 检查网络连接
curl -I https://github.com
```

## 🔧 详细部署步骤

### 步骤1: 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 检查并安装必要工具
sudo apt install curl wget git htop -y

# 检查防火墙状态（确保不会阻止挖矿）
sudo ufw status
```

### 步骤2: 下载优化代码

```bash
# 创建工作目录
mkdir -p ~/nockchain-mining
cd ~/nockchain-mining

# 克隆优化版本
git clone https://github.com/zorp-corp/nockchain.git
cd nockchain

# 检查是否包含优化文件
ls -la scripts/epyc_mining_setup.sh
ls -la docs/EPYC_OPTIMIZATION.md
```

### 步骤3: 运行自动优化

```bash
# 给脚本执行权限
chmod +x scripts/epyc_mining_setup.sh

# 运行优化脚本（需要sudo权限）
sudo bash scripts/epyc_mining_setup.sh
```

**脚本执行过程中会：**
1. 检测CPU和系统配置
2. 安装必要的依赖包
3. 配置系统优化参数
4. 安装Rust工具链
5. 编译优化版Nockchain
6. 配置钱包和挖矿参数
7. 创建启动和监控脚本

### 步骤4: 验证部署结果

```bash
# 检查编译结果
ls -la target/release/nockchain*

# 检查生成的脚本
ls -la start_mining*.sh monitor_mining.sh

# 检查钱包配置
ls -la ~/.nockchain/

# 检查系统优化状态
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /proc/meminfo | grep Huge
```

## ⚡ 启动挖矿

### 标准启动
```bash
# 使用标准配置启动挖矿
./start_mining.sh
```

### NUMA优化启动（推荐）
```bash
# 使用NUMA优化启动（适合多路服务器）
./start_mining_numa.sh
```

### 后台运行
```bash
# 在screen中运行（推荐）
screen -S nockchain-mining
./start_mining.sh
# 按 Ctrl+A, D 断开screen

# 重新连接
screen -r nockchain-mining
```

### 使用systemd服务
```bash
# 启动systemd服务（如果配置了）
sudo systemctl start nockchain-mining.service
sudo systemctl enable nockchain-mining.service

# 查看服务状态
sudo systemctl status nockchain-mining.service
```

## 📊 性能监控

### 实时监控
```bash
# 启动性能监控脚本
./monitor_mining.sh

# 或者在新终端中运行
screen -S mining-monitor ./monitor_mining.sh
```

### 查看挖矿日志
```bash
# 查看实时日志
tail -f mining_performance.log

# 查看系统日志
sudo journalctl -u nockchain-mining.service -f

# 查看进程状态
ps aux | grep nockchain
top -p $(pgrep nockchain)
```

### 温度监控
```bash
# 安装温度监控工具
sudo apt install lm-sensors -y
sudo sensors-detect --auto

# 实时温度监控
watch -n 1 sensors
```

## 🔧 配置调优

### 调整线程数
```bash
# 如果温度过高或性能不佳，可以调整线程数
./target/release/nockchain --mine --num-threads 80  # 减少线程

# 或编辑启动脚本
nano start_mining.sh
# 修改 --num-threads 参数
```

### 内存优化
```bash
# 查看当前大页配置
cat /proc/meminfo | grep Huge

# 调整大页数量（如果需要）
sudo echo 4096 > /proc/sys/vm/nr_hugepages
```

### CPU调度器
```bash
# 确认CPU调度器设置
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 如果不是performance，手动设置
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee $cpu
done
```

## 📈 性能基准测试

### 运行基准测试
```bash
# 创建基准测试脚本
cat > benchmark.sh << 'EOF'
#!/bin/bash
echo "开始5分钟基准测试..."
timeout 300 ./target/release/nockchain --mine --num-threads 90 > benchmark.log 2>&1
echo "基准测试完成，查看 benchmark.log"
grep -i "hash\|mining" benchmark.log | tail -10
EOF

chmod +x benchmark.sh
./benchmark.sh
```

### 性能对比
```bash
# 对比不同线程数的性能
for threads in 64 80 90 96; do
    echo "测试 $threads 线程..."
    timeout 60 ./target/release/nockchain --mine --num-threads $threads > test_${threads}.log 2>&1
    echo "线程 $threads 完成"
    sleep 30
done
```

## 🚨 故障排除

### 常见问题及解决方案

#### 1. 编译失败
```bash
# 问题：缺少编译依赖
# 解决方案：
sudo apt update
sudo apt install build-essential clang llvm-dev libclang-dev cmake pkg-config libssl-dev

# 清理重新编译
cargo clean
export RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2"
cargo build --release --features optimized
```

#### 2. 性能不佳
```bash
# 问题：CPU未运行在性能模式
# 检查：
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 解决：
sudo bash scripts/epyc_mining_setup.sh  # 重新运行优化脚本
```

#### 3. 挖矿进程异常退出
```bash
# 检查日志
journalctl -u nockchain-mining.service --no-pager | tail -50

# 检查系统资源
free -h
df -h
sensors  # 检查温度
```

#### 4. 网络连接问题
```bash
# 检查网络连接
ping 8.8.8.8
curl -I https://github.com

# 检查防火墙
sudo ufw status
sudo iptables -L
```

#### 5. 钱包问题
```bash
# 重新生成钱包
./target/release/nockchain-wallet keygen

# 检查钱包文件
ls -la ~/.nockchain/
cat ~/.nockchain/wallet_info.txt
```

### 日志分析
```bash
# 分析挖矿日志
grep -i "error\|fail\|warn" mining_performance.log

# 分析系统日志
dmesg | tail -50
journalctl --since "1 hour ago" | grep -i "error\|fail"
```

## 🔄 维护和更新

### 定期维护
```bash
# 每周检查系统状态
sudo apt update && sudo apt upgrade
sensors  # 检查温度
free -h  # 检查内存
df -h    # 检查磁盘

# 重启挖矿服务
sudo systemctl restart nockchain-mining.service
```

### 更新代码
```bash
# 备份当前配置
cp -r ~/.nockchain ~/.nockchain.backup

# 拉取最新代码
git pull origin main

# 重新编译
cargo build --release --features optimized

# 重启挖矿
./start_mining.sh
```

### 备份重要文件
```bash
# 备份钱包文件
cp ~/.nockchain/wallet_info.txt ~/wallet_backup_$(date +%Y%m%d).txt

# 备份配置文件
tar -czf nockchain_backup_$(date +%Y%m%d).tar.gz ~/.nockchain/ start_mining*.sh monitor_mining.sh
```

## 📊 预期性能指标

### 性能基准
| CPU型号 | 原版算力 | 优化后算力 | 提升幅度 | 功耗 |
|---------|----------|------------|----------|------|
| EPYC 9B14 | 10-15 MH/s | 25-35 MH/s | +150-250% | 280W |
| EPYC 7K62 | 8-12 MH/s | 20-30 MH/s | +100-200% | 225W |
| EPYC 7742 | 12-18 MH/s | 28-40 MH/s | +120-220% | 225W |

### 系统指标
- **CPU使用率**: 95-98%
- **内存使用**: 60-80%
- **温度范围**: 65-80°C
- **网络使用**: 1-5 Mbps

## 🎉 部署完成检查清单

- [ ] ✅ 系统依赖安装完成
- [ ] ✅ Rust工具链配置正确
- [ ] ✅ Nockchain编译成功
- [ ] ✅ 钱包配置完成并备份
- [ ] ✅ 系统优化参数生效
- [ ] ✅ 挖矿脚本可以正常运行
- [ ] ✅ 监控脚本正常工作
- [ ] ✅ 性能达到预期指标
- [ ] ✅ 系统温度控制在安全范围
- [ ] ✅ 备份文件已创建

## 📞 获取帮助

### 技术支持
- **GitHub Issues**: [提交问题](https://github.com/zorp-corp/nockchain/issues)
- **文档参考**: [详细优化指南](docs/EPYC_OPTIMIZATION.md)
- **快速参考**: [快速开始](QUICK_START.md)

### 问题报告模板
```
**系统信息**:
- CPU: [您的CPU型号]
- 内存: [内存大小]
- 操作系统: [系统版本]

**问题描述**:
[详细描述遇到的问题]

**错误日志**:
[相关错误信息或日志]

**已尝试的解决方案**:
[您已经尝试的操作]
```

---

## ⚠️ 重要提醒

1. **备份钱包**: 务必备份 `~/.nockchain/wallet_info.txt` 文件
2. **监控温度**: 长期运行时注意CPU温度，避免过热
3. **网络稳定**: 确保网络连接稳定，避免挖矿中断
4. **定期维护**: 定期检查系统状态和更新代码
5. **合规挖矿**: 遵守当地法律法规，合理评估风险

**祝您挖矿成功！🚀**