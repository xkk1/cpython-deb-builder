# CPython Debian 自动打包脚本

一个 **独立、可定制、不与系统 Python 冲突** 的 CPython → Debian `.deb` 自动打包脚本。

该脚本可用于：

- 构建 **任意版本** CPython
- 生成 **独立前缀** 的 Python 安装（不污染系统 Python）
- 自动生成 `debian/` 打包骨架
- 调用 `dpkg-buildpackage` 构建标准 Debian 包
- 可选 **free-threaded (no GIL)** 构建
- 可选 **GPG 签名**

---

## ✨ 特性

- 📦 **标准 Debian 打包**
  - 自动生成 `debian/control`、`rules`、`changelog` 等
  - 使用 `debhelper-compat (= 13)`
- 🐍 **任意 CPython 版本**
  - `3.x.y` / `alpha` / `beta` / `rc`
- 🧩 **不与系统 Python 冲突**
  - 自定义包名
  - 自定义安装前缀（如 `/usr/lib/python3.14-xkk1`）
- 🚀 **性能优化**
  - `--enable-optimizations`
  - `--with-lto=full`
  - 可选 JIT / free-threaded
- 🔐 **可选 GPG 签名**
- 🧹 **构建完成自动清理**

---

## 📦 构建结果示例

```text
python3.14-xkk1_3.14.2-1xkk1_amd64.deb
python3.14-xkk1_3.14.2-1xkk1_amd64.buildinfo
python3.14-xkk1_3.14.2-1xkk1_amd64.changes
python3.14-xkk1_3.14.2-1xkk1.debian.tar.xz
python3.14-xkk1_3.14.2-1xkk1.dsc
python3.14-xkk1_3.14.2.orig.tar.xz
python3.14-xkk1-dbgsym_3.14.2-1xkk1_amd64.ddeb
```

---

## 🔧 构建环境要求

### 操作系统

* Debian / Ubuntu（推荐较新版本）

### 基本工具

```bash
sudo apt install \
  build-essential \
  debhelper
```

> **可选软件包：**
> 
> - `wget`：未提供源码时，源码包下载工具

>  **注意：** Ubuntu 24.04.3 LTS 在打包 Python3.14 时依赖包 autoconf >= 2.72，apt 仓库只提供 autoconf 2.71，请自行编译安装 autoconf 2.72。


### CPython 构建依赖（脚本中已声明）

```bash
sudo apt install \
  build-essential \
  pkg-config \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  liblzma-dev \
  libffi-dev \
  libreadline-dev \
  libsqlite3-dev \
  libncurses-dev \
  libgdbm-dev \
  libgdbm-compat-dev \
  libnss3-dev \
  uuid-dev \
  tk-dev \
  libzstd-dev
```

> **可选软件包：**
> 
> - `clang-19`：用于 JIT 编译

---

## 🚀 使用方法

### 1️⃣ 克隆仓库

```bash
git clone https://github.com/xkk1/cpython-deb-builder.git
cd cpython-deb-builder
```

### 2️⃣ 修改脚本配置

编辑 `cpython-deb-builder.sh` 顶部变量：

```sh
PY_MAJOR="3"
PY_MINOR="14"
PY_MICRO="2"
PY_RELEASE=""

PACKAGER="xkk1"
FREE_THREADED="false"
SIGN_KEY="BDB382089DBA3BE895E744712272FE35343C6BC8"
```

### 3️⃣ 运行脚本

```bash
chmod +x cpython-deb-builder.sh
./cpython-deb-builder.sh
```

构建过程中会：

* 自动下载 CPython 源码（如不存在）
* 生成 Debian 打包骨架
* 等待确认后开始构建

---

## 📁 安装布局说明

默认安装前缀示例：

```text
/usr/lib/python3.14-xkk1/
├── bin/
│   ├── python3.14
│   ├── pip3.14
│   └── ...
```

### 自动创建的软链接

安装后会在以下位置创建软链接（如不存在）：

```text
/usr/bin/python3.14
/usr/bin/python3.14-xkk1
/usr/lib/python3.14-xkk1/bin/python3.14-xkk1
```

卸载时会自动清理这些链接。

---

## 🧠 设计理念

* **不替换系统 Python**
* **不使用 alternatives**
* **前缀隔离**
* **完全符合 Debian Policy**
* **脚本即工具，不依赖复杂框架**

---

## ⚠️ 注意事项

* 本项目 **不是 Debian 官方 Python 包**
* 目前只测试 Python3.14

---

## 📜 License

GPL-3.0 License

---

欢迎 issue / PR / 讨论
