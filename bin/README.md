# 预编译二进制文件

此目录存放 lookbusy 的预编译二进制文件，用于免编译安装。

## 如何生成

在对应架构的 Linux 机器上执行：

```bash
# 下载源码
curl -L http://www.devin.com/lookbusy/download/lookbusy-1.4.tar.gz -o lookbusy-1.4.tar.gz
tar -xzf lookbusy-1.4.tar.gz && cd lookbusy-1.4

# 编译
./configure && make

# 复制二进制文件（根据架构命名）
# AMD64 机器：
cp lookbusy ../lookbusy-amd64

# ARM64 机器：
cp lookbusy ../lookbusy-arm64
```

## 文件说明

| 文件 | 架构 | 适用场景 |
|------|------|----------|
| `lookbusy-amd64` | x86_64 | 甲骨文 AMD 实例 |
| `lookbusy-arm64` | aarch64 | 甲骨文 ARM (Ampere) 实例 |
