# 🚀 Nockchain EPYC 快速开始

## 一键部署（推荐）

```bash
# 直接运行优化脚本
curl -sSL https://raw.githubusercontent.com/zorp-corp/nockchain/main/scripts/epyc_mining_setup.sh | bash
```

## 手动部署

### 1. 克隆仓库
```bash
git clone https://github.com/zorp-corp/nockchain.git
cd nockchain
```

### 2. 运行优化脚本
```bash
chmod +x scripts/epyc_mining_setup.sh
sudo bash scripts/epyc_mining_setup.sh
```

### 3. 开始挖矿
```bash
# 脚本完成后会自动询问是否开始挖矿
# 或者手动运行：
./start_mining.sh
```

## 命令参考

```bash
# 标准挖矿
./start_mining.sh

# NUMA优化挖矿
./start_mining_numa.sh

# 性能监控
./monitor_mining.sh

# 检查挖矿状态
ps aux | grep nockchain

# 查看算力
tail -f mining_performance.log
```

## 预期性能

| CPU型号 | 预期算力 | 提升幅度 |
|---------|----------|----------|
| EPYC 9B14 | 25-35 MH/s | +150-250% |
| EPYC 7K62 | 20-30 MH/s | +100-200% |

## 故障排除

### 编译失败
```bash
sudo apt install clang llvm-dev libclang-dev
cargo clean && cargo build --release --features optimized
```

### 性能不佳
```bash
# 检查CPU调度器
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# 应该显示 "performance"
```

### 温度过高
```bash
# 监控温度
sensors

# 降低线程数
./target/release/nockchain --mine --num-threads 80
```

## 支持

- **详细文档**: [docs/EPYC_OPTIMIZATION.md](docs/EPYC_OPTIMIZATION.md)
- **GitHub Issues**: 提交技术问题
- **性能报告**: 分享优化效果

---

**重要**: 请备份您的钱包信息（`~/.nockchain/wallet_info.txt`）！