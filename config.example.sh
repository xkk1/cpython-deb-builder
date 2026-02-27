#!./cpython-deb-builder.sh -c
# 默认配置
# 准备 Python 源码文件 Python-x.y.z.tar.xz，没有脚本从官网下载
py_major="${py_major:-3}"  # 主版本 x
py_minor="${py_minor:-14}"  # 副版本 y
py_micro="${py_micro:-2}"  # 小版本 z
py_release="${py_release:-}"  # 可选: a1(alpha), b1(beta), rc1, 空字符串表示稳定版
# 动态拼接 Python 主版本号 x.y --- 3.14
py_main_version="${py_main_version:-${py_major}.${py_minor}}"
# 动态拼接 Python 完整版本号 x.y.z --- 3.14.2
py_full_version="${py_full_version:-${py_main_version}.${py_micro}${py_release}}"
# python 源码文件
PY_SRC="Python-${py_full_version}.tar.xz"
# 是否启用 free-threaded (no GIL) 支持，默认关闭 'false' 启用 ‘true'
free_threaded="${free_threaded:-false}"
# 打包者
packager="${packager:-xkk}"
maintainer="${maintainer:-${packager} <xkk1@120107.xyz>}"
# Debian 包修订版本号
debian_revision="1${packager}1"
# GPG 签名，不使用将 sign_key 设置为空
# sign_key="${sign_key:-BDB382089DBA3BE895E744712272FE35343C6BC8}"
sign_key="${sign_key:-}"
# 构建类型 dpkg-buildpackage --build=$build_type
# 可选参数:
#   full: 默认值，包含所有文件
#   binary: 只包含可执行文件
#   source: 只包含源码文件
build_type="${build_type:-full}"
# 构建完，删除源码文件 默认'false'
cleanup_source="${cleanup_source:-true}"
# 构建完，删除构建临时文件标志变量 默认'true'
cleanup_build_temp="${cleanup_build_temp:-true}"

# 安装目录
prefix="${prefix:-/usr/lib/python${py_main_version}-${packager}}"
# 配置参数
if [ -z "${configure_args+set}" ]; then
    configure_args=$(cat << EOF
--prefix=${prefix}
EOF
)
fi
# free-threaded (no GIL) 配置参数，一行一个参数
if [ -z "${free_threaded_configure_args+set}" ]; then
    free_threaded_configure_args=$(cat << EOF
--prefix=${prefix}
--disable-gil
EOF
)
fi

# 编译依赖，一行一个依赖
if [ -z "${build_depends+set}" ]; then
    build_depends=$(cat << EOF
build-essential
clang-19
pkg-config
libssl-dev
zlib1g-dev
libbz2-dev
liblzma-dev
libffi-dev
libreadline-dev
libsqlite3-dev
libncurses-dev
libgdbm-dev
libgdbm-compat-dev
libnss3-dev
uuid-dev
tk-dev
libzstd-dev
EOF
)
fi

# Makefile Git 信息替换
# GITVERSION=	git --git-dir $(srcdir)/.git rev-parse --short HEAD
# GITTAG=		git --git-dir $(srcdir)/.git describe --all --always --dirty
# GITBRANCH=	git --git-dir $(srcdir)/.git name-rev --name-only HEAD
GITVERSION="${GITVERSION:-}"
GITTAG="${GITTAG:-echo tags/v${py_full_version}}"
GITBRANCH="${GITBRANCH:-echo main}"
# platform.python_revision() = GITVERSION or ''
# platform.python_build()[0] = GITTAG + ':' + GITVERSION or GITTAG or 'main:' + GITVERSION or GITBRANCH or 'main'
# platform.python_branch() = GITTAG or GITBRANCH

# 根据 free_threaded 选项添加 nogil 标记
if [ "$free_threaded" = "true" ]; then
    configure_args="${free_threaded_configure_args}"
    version_variant_suffix="${version_variant_suffix:-+nogil}"
    package_variant_suffix="${package_variant_suffix:--nogil}"
    # python 可执行文件后缀
    executable_variant_suffix="${executable_variant_suffix:-t}"
else
    version_variant_suffix="${version_variant_suffix:-}"
    package_variant_suffix="${package_variant_suffix:-}"
    executable_variant_suffix="${executable_variant_suffix:-}"
fi

# deb 包名
deb_package_name="${deb_package_name:-python${py_main_version}-${packager}${package_variant_suffix}}"
# deb 包版本号
deb_package_version="${deb_package_version:-${py_full_version}-${debian_revision}}"
# 架构
arch="${arch:-$(dpkg --print-architecture)}"
# 构建目录，构建产物在构建目录的上层目录
build_dir="${build_dir:-$(pwd -P)/${deb_package_name}}"
