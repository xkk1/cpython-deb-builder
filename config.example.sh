#!./cpython-deb-builder.sh -c
# 默认配置
# 准备 Python 源码文件 Python-x.y.z.tar.xz，没有脚本从官网下载
PY_MAJOR="${PY_MAJOR:-3}"  # 主版本 x
PY_MINOR="${PY_MINOR:-14}"  # 副版本 y
PY_MICRO="${PY_MICRO:-2}"  # 小版本 z
PY_RELEASE="${PY_RELEASE:-}"  # 可选: a1(alpha), b1(beta), rc1, 空字符串表示稳定版
# 动态拼接 Python 主版本号 x.y --- 3.14
PY_MAIN_VERSION="${PY_MAIN_VERSION:-${PY_MAJOR}.${PY_MINOR}}"
# 动态拼接 Python 完整版本号 x.y.z --- 3.14.2
PY_FULL_VERSION="${PY_FULL_VERSION:-${PY_MAIN_VERSION}.${PY_MICRO}${PY_RELEASE}}"
# python 源码文件
PY_SRC="Python-${PY_FULL_VERSION}.tar.xz"
# 是否启用 free-threaded (no GIL) 支持，默认关闭 'false' 启用 ‘true'
FREE_THREADED="${FREE_THREADED:-false}"
# 打包者
PACKAGER="${PACKAGER:-xkk}"
MAINTAINER="${MAINTAINER:-${PACKAGER} <xkk1@120107.xyz>}"
# Debian 包修订版本号
DEBIAN_REVISION="1${PACKAGER}1"
# GPG 签名，不使用将 SIGN_KEY 设置为空
# SIGN_KEY="${SIGN_KEY:-BDB382089DBA3BE895E744712272FE35343C6BC8}"
SIGN_KEY="${SIGN_KEY:-}"
# 构建类型 dpkg-buildpackage --build=$BUILD_TYPE
# 可选参数:
#   full: 默认值，包含所有文件
#   binary: 只包含可执行文件
#   source: 只包含源码文件
BUILD_TYPE="${BUILD_TYPE:-full}"
# 构建完，删除源码文件 默认'false'
CLEANUP_SOURCE="${CLEANUP_SOURCE:-true}"
# 构建完，删除构建临时文件标志变量 默认'true'
CLEANUP_BUILD_TEMP="${CLEANUP_BUILD_TEMP:-true}"

# 安装目录
PREFIX="${PREFIX:-/usr/lib/python${PY_MAIN_VERSION}-${PACKAGER}}"
# 配置参数
if [ -z "${CONFIGURE_ARGS+set}" ]; then
    CONFIGURE_ARGS=$(cat << EOF
--prefix=${PREFIX}
EOF
)
fi
# free-threaded (no GIL) 配置参数
if [ -z "${FREE_THREADED_CONFIGURE_ARGS+set}" ]; then
    FREE_THREADED_CONFIGURE_ARGS=$(cat << EOF
--prefix=${PREFIX}
--disable-gil
EOF
)
fi

# Makefile Git 信息替换
# GITVERSION=	git --git-dir $(srcdir)/.git rev-parse --short HEAD
# GITTAG=		git --git-dir $(srcdir)/.git describe --all --always --dirty
# GITBRANCH=	git --git-dir $(srcdir)/.git name-rev --name-only HEAD
GITVERSION="${GITVERSION:-}"
GITTAG="${GITTAG:-echo tags/v${PY_FULL_VERSION}}"
GITBRANCH="${GITBRANCH:-echo main}"
# platform.python_revision() = GITVERSION or ''
# platform.python_build()[0] = GITTAG + ':' + GITVERSION or GITTAG or 'main:' + GITVERSION or GITBRANCH or 'main'
# platform.python_branch() = GITTAG or GITBRANCH

# 根据 FREE_THREADED 选项添加 nogil 标记
if [ "$FREE_THREADED" = "true" ]; then
    CONFIGURE_ARGS="${FREE_THREADED_CONFIGURE_ARGS}"
    VERSION_VARIANT_SUFFIX="${VERSION_VARIANT_SUFFIX:-+nogil}"
    PACKAGE_VARIANT_SUFFIX="${PACKAGE_VARIANT_SUFFIX:--nogil}"
    # python 可执行文件后缀
    EXECUTABLE_VARIANT_SUFFIX="${EXECUTABLE_VARIANT_SUFFIX:-t}"
else
    VERSION_VARIANT_SUFFIX="${VERSION_VARIANT_SUFFIX:-}"
    PACKAGE_VARIANT_SUFFIX="${PACKAGE_VARIANT_SUFFIX:-}"
    EXECUTABLE_VARIANT_SUFFIX="${EXECUTABLE_VARIANT_SUFFIX:-}"
fi

# deb 包名
DEB_PACKAGE_NAME="${DEB_PACKAGE_NAME:-python${PY_MAIN_VERSION}-${PACKAGER}${PACKAGE_VARIANT_SUFFIX}}"
# deb 包版本号
DEB_PACKAGE_VERSION="${DEB_PACKAGE_VERSION:-${PY_FULL_VERSION}-${DEBIAN_REVISION}}"
# 架构
ARCH="${ARCH:-$(dpkg --print-architecture)}"
# 构建目录，构建产物在构建目录的上层目录
BUILD_DIR="${BUILD_DIR:-$(pwd -P)/${DEB_PACKAGE_NAME}}"
# 产物目录（构建目录的上级）
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$BUILD_DIR")}"
