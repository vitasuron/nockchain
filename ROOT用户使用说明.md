# 🚀 Nockchain EPYC Root用户一键挖矿指南

## 📋 专为ROOT用户设计

您好！这是专门为root用户设计的Nockchain EPYC优化方案，一条命令即可完成所有配置并开始高效挖矿。

## ⚡ 一键部署命令

### 在您的EPYC服务器上，以root用户身份运行：

```bash
# 方式1: 直接从GitHub运行（推荐）
curl -sSL https://raw.githubusercontent.com/您的用户名/nockchain/main/scripts/epyc_mining_setup_root.sh | bash

# 方式2: 先下载再运行
wget https://raw.githubusercontent.com/您的用户名/nockchain/main/scripts/epyc_mining_setup_root.sh
chmod +x epyc_mining_setup_root.sh
./epyc_mining_setup_root.sh
```

## 📊 自动完成的优化

脚本会自动完成以下操作：

1. ✅ **系统检测**: 自动识别EPYC型号和配置
2. ✅ **依赖安装**: 安装所有必要的开发工具
3. ✅ **系统优化**: CPU性能模式、内存大页、NUMA优化
4. ✅ **Rust安装**: 自动安装和配置Rust工具链
5. ✅ **代码编译**: 使用EPYC特定优化编译Nockchain
6. ✅ **钱包配置**: 自动生成挖矿钱包和密钥
7. ✅ **脚本生成**: 创建启动、监控和管理脚本
8. ✅ **系统服务**: 配置systemd服务便于管理

## 🎯 预期性能提升

| 您的服务器 | 优化前算力 | 优化后算力 | 性能提升 |
|------------|------------|------------|----------|
| **EPYC 9B14** | 10-15 MH/s | **25-35 MH/s** | **+150-250%** 🔥 |
| **EPYC 7K62 双路** | 8-12 MH/s | **20-30 MH/s** | **+100-200%** 🔥 |

## 🚀 部署后使用

### 挖矿启动命令
```bash
# 前台启动（推荐用于测试）
cd /opt/nockchain && ./start_mining.sh

# NUMA优化启动（多路服务器推荐）
cd /opt/nockchain && ./start_mining_numa.sh

# 后台服务启动
systemctl start nockchain-mining
systemctl enable nockchain-mining  # 开机自启
```

### 监控和管理
```bash
# 性能监控
cd /opt/nockchain && ./monitor_mining.sh

# 查看服务状态
systemctl status nockchain-mining

# 查看挖矿日志
journalctl -u nockchain-mining -f

# 停止挖矿
systemctl stop nockchain-mining
```

## 🔑 钱包管理

### 重要文件位置
- **钱包信息**: `/root/.nockchain/wallet_info.txt`
- **备份文件**: `/root/.nockchain/wallet_backup_*.txt`
- **环境配置**: `/root/.nockchain/.env`

### 钱包备份（重要！）
```bash
# 备份钱包文件到安全位置
cp /root/.nockchain/wallet_info.txt /root/钱包备份_$(date +%Y%m%d).txt

# 查看钱包公钥
cat /root/.nockchain/.env
```

## 📈 性能调优

### 如果温度过高
```bash
# 检查温度
sensors

# 降低线程数（编辑启动脚本）
nano /opt/nockchain/start_mining.sh
# 修改 --num-threads 参数，比如从96改为80
```

### 如果性能不理想
```bash
# 检查CPU调度器
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# 应该显示 "performance"

# 检查大页内存
cat /proc/meminfo | grep Huge

# 重新运行优化脚本
./epyc_mining_setup_root.sh
```

## 🔧 故障排除

### 常见问题

#### 1. 脚本执行失败
```bash
# 确保root权限
whoami  # 应该显示 "root"

# 检查网络连接
ping -c 3 github.com

# 重新下载脚本
rm -f epyc_mining_setup_root.sh
curl -sSL https://raw.githubusercontent.com/您的用户名/nockchain/main/scripts/epyc_mining_setup_root.sh -o epyc_mining_setup_root.sh
chmod +x epyc_mining_setup_root.sh
./epyc_mining_setup_root.sh
```

#### 2. 编译失败
```bash
# 检查依赖
apt update && apt install -y build-essential clang

# 清理重新编译
cd /opt/nockchain
cargo clean
cargo build --release
```

#### 3. 挖矿无法启动
```bash
# 检查钱包配置
cat /root/.nockchain/.env

# 检查网络端口
netstat -tulpn | grep nockchain

# 查看详细错误
cd /opt/nockchain
./start_mining.sh
```

## 📞 获取帮助

### 技术支持
- **详细文档**: `/opt/nockchain/docs/`
- **日志文件**: `/opt/nockchain/mining_performance.log`
- **系统日志**: `journalctl -u nockchain-mining`

### 性能报告
请分享您的优化效果：
- CPU型号: `lscpu | grep "Model name"`
- 优化前后算力对比
- 系统配置信息

## ⚠️ 重要提醒

1. **🔐 备份钱包**: 务必备份 `/root/.nockchain/wallet_info.txt`
2. **🌡️ 监控温度**: 使用 `sensors` 命令监控CPU温度
3. **🔌 稳定电源**: 确保服务器电源和网络稳定
4. **📊 定期检查**: 监控挖矿性能和系统状态
5. **⚖️ 合规挖矿**: 遵守当地法律法规

## 🎉 开始您的高效挖矿之旅！

```bash
# 立即开始：
curl -sSL https://raw.githubusercontent.com/您的用户名/nockchain/main/scripts/epyc_mining_setup_root.sh | bash
```

---

**祝您挖矿成功，收益丰厚！🚀💰**