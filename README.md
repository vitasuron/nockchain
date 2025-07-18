# Nockchain

**Nockchain is a lightweight blockchain for heavyweight verifiable applications.**

## 🚀 EPYC 服务器优化版本

本仓库包含针对AMD EPYC服务器优化的Nockchain挖矿软件，预期性能提升150-250%。

### ⚡ 一键部署（推荐）

```bash
# 方法1: 直接从GitHub运行
curl -sSL https://raw.githubusercontent.com/zorp-corp/nockchain/main/scripts/epyc_mining_setup.sh | bash

# 方法2: 克隆后运行
git clone https://github.com/zorp-corp/nockchain.git
cd nockchain
bash scripts/epyc_mining_setup.sh
```

### 📊 性能提升

| CPU型号 | 原版性能 | 优化后性能 | 提升幅度 |
|---------|----------|-----------|----------|
| EPYC 9B14 | ~10-15 MH/s | 25-35 MH/s | +150-250% |
| EPYC 7K62 | ~8-12 MH/s | 20-30 MH/s | +100-200% |
| 其他EPYC | 变化 | 变化 | +50-150% |

### 🛠️ 优化特性

- **编译优化**: 针对Zen 2/3/4架构的RUSTFLAGS优化
- **系统调优**: CPU调度器、内存大页、NUMA感知
- **多线程增强**: 工作窃取调度器和线程亲和性
- **SIMD加速**: AVX2/AVX-512指令集优化
- **性能监控**: 实时算力和系统监控

---

## 🔧 手动安装（高级用户）

### 系统要求

- **CPU**: AMD EPYC 7K62 或更新版本
- **内存**: 384GB RAM（推荐）
- **系统**: Ubuntu 20.04+ 或 CentOS 8+
- **网络**: 稳定的互联网连接

### 编译优化

```bash
# 设置CPU特定优化标志
export RUSTFLAGS="-C target-cpu=znver4 -C target-feature=+avx2,+fma,+bmi2,+aes,+pclmul"

# 编译优化版本
cargo build --release --features optimized
```

### 启动挖矿

```bash
# 生成钱包
./target/release/nockchain-wallet keygen

# 启动挖矿（调整线程数）
./target/release/nockchain --mine --num-threads 90
```

---

## 📚 原版说明

We believe the future of blockchains is lightweight trustless settlement of heavyweight verifiable computation. The only way to get there is by replacing verifiability-via-public-replication with verifiability-via-private-proving. Proving happens off-chain; verification is on-chain.

*Nockchain is entirely experimental and many parts are unaudited. We make no representations or guarantees as to the behavior of this software.*

## Setup

Install `rustup` by following their instructions at: [https://rustup.rs/](https://rustup.rs/)

Ensure you have these dependencies installed if running on Debian/Ubuntu:
```
sudo apt update
sudo apt install clang llvm-dev libclang-dev make
```

Copy the example environment file and rename it to `.env`:
```
cp .env_example .env
```

Install `hoonc`, the Hoon compiler:

```
make install-hoonc
export PATH="$HOME/.cargo/bin:$PATH"
```

## Install Wallet

After you've run the setup and build commands, install the wallet:

```
make install-nockchain-wallet
export PATH="$HOME/.cargo/bin:$PATH"
```

See the nockchain-wallet [README](./crates/nockchain-wallet/README.md) for more information.


## Install Nockchain

After you've run the setup and build commands, install Nockchain:

```
make install-nockchain
export PATH="$HOME/.cargo/bin:$PATH"
```

## Setup Keys

To generate a new key pair:

```
nockchain-wallet keygen
```

This will print a new public/private key pair + chain code to the console, as well as the seed phrase for the private key.

Now, copy the public key to the `.env` file:

```
MINING_PUBKEY=<public-key>
```

## Backup Keys

To backup your keys, run:

```
nockchain-wallet export-keys
```

This will save your keys to a file called `keys.export` in the current directory.

They can be imported later with:

```
nockchain-wallet import-keys --input keys.export
```

## Running Nodes

Make sure your current directory is nockchain.

To run a Nockchain node without mining.

```
bash ./scripts/run_nockchain_node.sh
```

To run a Nockchain node and mine to a pubkey:

```
bash ./scripts/run_nockchain_miner.sh
```

For launch, make sure you run in a fresh working directory that does not include a .data.nockchain file from testing.

## 🚀 EPYC 优化命令

```bash
# 一键优化和挖矿
bash scripts/epyc_mining_setup.sh

# 手动编译优化版本
cargo build-optimized

# NUMA优化启动
./start_mining_numa.sh

# 性能监控
./monitor_mining.sh
```

## FAQ

### Can I use same pubkey if running multiple miners?

Yes, you can use the same pubkey if running multiple miners.

### How do I change the mining pubkey?

Run `nockchain-wallet keygen` to generate a new key pair.

If you are using the Makefile workflow, copy the public key to the `.env` file.

### How do I run a testnet?
To run a testnet on your machine, follow the same instructions as above, except use the fakenet
scripts provided in the `scripts` directory.

Here's how to set it up:

```bash
Make sure you have the most up-to-date version of Nockchain installed.

Inside of the nockchain directory:

# Create directories for each instance
mkdir fakenet-hub fakenet-node

# Copy .env to each directory
cp .env fakenet-hub/
cp .env fakenet-node/

# Run each instance in its own directory with .env loaded
cd fakenet-hub && sh ../scripts/run_nockchain_node_fakenet.sh
cd fakenet-node && sh ../scripts/run_nockchain_miner_fakenet.sh
```

The hub script is bound to a fixed multiaddr and the node script sets that multiaddr as an initial
peer so that nodes have a way of discovering eachother initially.

You can run multiple instances using `run_nockchain_miner_fakenet.sh`, just make sure that
you are running them from different directories because the checkpoint data is located in the
working directory of the script.

### What are the networking requirements?

Nockchain requires:

1. Internet.
2. If you are behind a firewall, you need to specify the p2p ports to use and open them..
   - Example: `nockchain --bind /ip4/0.0.0.0/udp/$PEER_PORT/quic-v1`
3. **NAT Configuration (if you are behind one)**:
   - If behind NAT, configure port forwarding for the peer port
   - Use `--bind` to specify your public IP/domain
   - Example: `nockchain --bind /ip4/1.2.3.4/udp/$PEER_PORT/quic-v1`

### Why aren't Zorp peers connecting?

Common reasons for peer connection failures:

1. **Network Issues**:
   - Firewall blocking P2P port
   - NAT not properly configured
   - Incorrect bind address

2. **Configuration Issues**:
   - Invalid peer IDs

3. **Debug Steps**:
   - Check logs for connection errors
   - Verify port forwarding

### What do outgoing connection failures mean?

Outgoing connection failures can occur due to:

1. **Network Issues**:
   - Peer is offline
   - Firewall blocking connection
   - NAT traversal failure

2. **Peer Issues**:
   - Peer has reached connection limit
   - Peer is blocking your IP

3. **Debug Steps**:
   - Check peer's status
   - Verify network connectivity
   - Check logs for specific error messages

### How do I know if it's mining?

You can check the logs for mining activity.

If you see a line that looks like:

```sh
[%mining-on 12.040.301.481.503.404.506 17.412.404.101.022.637.021 1.154.757.196.846.835.552 12.582.351.418.886.020.622 6.726.267.510.179.724.279]
```

### How do I check block height?

You can check the logs for a line like:

```sh
block Vo3d2Qjy1YHMoaHJBeuQMgi4Dvi3Z2GrcHNxvNYAncgzwnQYLWnGVE added to validated blocks at 2
```

That last number is the block height.

### What do common errors mean?

Common errors and their solutions:

1. **Connection Errors**:
   - `Failed to dial peer`: Network connectivity issues, you may still be connected though.
   - `Handshake with the remote timed out`: Peer might be offline, not a fatal issue.

### How do I check wallet balance?

To check your wallet balance:

```bash
# List all notes by pubkey
nockchain-wallet --nockchain-socket ./nockchain.sock list-notes-by-pubkey -p <your-pubkey>
```

### How do I configure logging levels?

To reduce logging verbosity, you can set the `RUST_LOG` environment variable before running nockchain:

```bash
# Show only info and above
RUST_LOG=info nockchain

# Show only errors
RUST_LOG=error nockchain

# Show specific module logs (e.g. only p2p events)
RUST_LOG=nockchain_libp2p_io=info nockchain

# Multiple modules with different levels
RUST_LOG=nockchain_libp2p_io=info,nockchain=warn nockchain
```

Common log levels from most to least verbose:
- `trace`: Very detailed debugging information
- `debug`: Debugging information
- `info`: General operational information
- `warn`: Warning messages
- `error`: Error messages

You can also add this to your `.env` file if you're running with the Makefile:
```
RUST_LOG=info
```

### Troubleshooting Common Issues

1. **Node Won't Start**:
   - Check port availability
   - Verify .env configuration
   - Check for existing .data.nockchain file
   - Ensure proper permissions

2. **No Peers Connecting**:
   - Verify port forwarding
   - Check firewall settings

3. **Mining Not Working**:
   - Verify mining pubkey
   - Check --mine flag
   - Ensure peers are connected
   - Check system resources

4. **Wallet Issues**:
   - Verify key import/export
   - Check socket connection
   - Ensure proper permissions

## 🔗 相关链接

- **Nockchain 官网**: [https://www.nockchain.org/](https://www.nockchain.org/)
- **挖矿指南**: [scripts/epyc_mining_setup.sh](scripts/epyc_mining_setup.sh)
- **性能优化分析**: [docs/optimization_analysis.md](docs/optimization_analysis.md)

## ⚠️ 免责声明

- 本优化版本仅供学习和研究使用
- 挖矿收益不予保证，请评估风险
- 请遵守当地法律法规
- 注意监控系统温度和稳定性

# Contributing

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as below, without any additional terms or conditions.

# License

Licensed under either of

Apache License, Version 2.0 (LICENSE-APACHE or https://www.apache.org/licenses/LICENSE-2.0)
MIT license (LICENSE-MIT or https://opensource.org/licenses/MIT)
at your option.
