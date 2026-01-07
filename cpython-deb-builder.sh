#!/usr/bin/env sh
#
# CPython Debian 自动打包脚本
# cpython-deb-builder.sh
#
# 自动下载 / 解压 CPython 源码，
# 生成 debian/ 打包骨架，
# 并调用 dpkg-buildpackage 构建 Debian 包
#

# 设置错误时退出
set -e
# 设置使用未定义变量时报错
set -u

# 准备 Python 源码文件 Python-x.y.z.tar.xz，没有脚本从官网下载
PY_MAJOR="3"  # 主版本 x
PY_MINOR="14"  # 副版本 y
PY_MICRO="2"  # 小版本 z
PY_RELEASE=""  # 可选: a1(alpha), b1(beta), rc1, 空字符串表示稳定版
# 动态拼接 Python 主版本号 3.14
PY_MAIN_VERSION="${PY_MAJOR}.${PY_MINOR}"
# 动态拼接 Python 完整版本号 3.14.2
PY_FULL_VERSION="${PY_MAIN_VERSION}.${PY_MICRO}${PY_RELEASE}"
# python 源码文件
PY_SRC="Python-${PY_FULL_VERSION}.tar.xz"
# 是否启用 free-threaded (no GIL) 支持，默认关闭 'false' 启用 ‘true'
FREE_THREADED="false"
# 打包者
PACKAGER="xkk1"
# Debian 包修订版本号
DEBIAN_REVISION="1${PACKAGER}"
# GPG 签名，不使用将 SIGN_KEY 设置为空
# SIGN_KEY=""
SIGN_KEY="BDB382089DBA3BE895E744712272FE35343C6BC8"
GPG_UID="${PACKAGER} <xkk1@120107.xyz>"
# 构建类型 dpkg-buildpackage --build=$BUILD_TYPE
# 可选参数:
#   full: 默认值，包含所有文件
#   binary: 只包含可执行文件
#   source: 只包含源码文件
BUILD_TYPE="full"
# 构建完，删除源码文件 默认'false'
CLEANUP_SOURCE="true"
# 构建完，删除构建临时文件标志变量 默认'true'
CLEANUP_BUILD_TEMP="true"

# 安装目录
PREFIX="/usr/lib/python${PY_MAIN_VERSION}-${PACKAGER}"
# 配置参数
CONFIGURE_ARGS=$(cat << EOF
--prefix=${PREFIX}
--enable-optimizations
--with-lto=full
--enable-experimental-jit=yes-off
EOF
)
# free-threaded (no GIL) 配置参数
FREE_THREADED_CONFIGURE_ARGS=$(cat << EOF
--prefix=${PREFIX}
--enable-optimizations
--with-lto=full
--disable-gil
EOF
)

# 根据 FREE_THREADED 选项添加 nogil 标记
if [ "$FREE_THREADED" = "true" ]; then
    CONFIGURE_ARGS="${FREE_THREADED_CONFIGURE_ARGS}"
    VERSION_VARIANT_SUFFIX="+nogil"
    PACKAGE_VARIANT_SUFFIX="-nogil"
    # python 可执行文件后缀
    # PYTHON="python${PY_MAIN_VERSION}${EXECUTABLE_VARIANT_SUFFIX}"
    EXECUTABLE_VARIANT_SUFFIX="t"
else
    VERSION_VARIANT_SUFFIX=""
    PACKAGE_VARIANT_SUFFIX=""
    EXECUTABLE_VARIANT_SUFFIX=""
fi

# deb 包名
DEB_PACKAGE_NAME="python${PY_MAIN_VERSION}-${PACKAGER}${PACKAGE_VARIANT_SUFFIX}"
# deb 包版本号
DEB_PACKAGE_VERSION="${PY_FULL_VERSION}-${DEBIAN_REVISION}"
# 架构
ARCH=$(dpkg --print-architecture)
# 构建目录，构建产物在构建目录的上层目录
BUILD_DIR="$(pwd -P)/${DEB_PACKAGE_NAME}"
# 产物目录（构建目录的上级）
OUTPUT_DIR=$(dirname "$BUILD_DIR")

# 输出构建信息
echo "============ CPython Debian 自动打包脚本 ============"
# echo "===================================================="
echo "Python 版本号: ${PY_FULL_VERSION}"
echo "free-threaded (no GIL) 支持: ${FREE_THREADED}"
echo "deb 包名: ${DEB_PACKAGE_NAME}"
echo "deb 包架构: ${ARCH}"
echo "deb 包版本号: ${DEB_PACKAGE_VERSION}"
echo "安装前缀: ${PREFIX}"
echo "构建目录: ${BUILD_DIR}"
echo "产物目录: ${OUTPUT_DIR}"
echo "配置参数: ./configure \\"
echo "$(printf '%s\n' "$CONFIGURE_ARGS" \
 | sed '$!s/$/ \\/' \
 | sed 's/^/\t/')"
echo "构建类型: dpkg-buildpackage --build=${BUILD_TYPE}"
if [ -n "$SIGN_KEY" ]; then
    echo "签名密钥: ${SIGN_KEY}"
    echo "GPG UID: ${GPG_UID}"
else
    echo "不启用签名"
fi
echo "构建完，删除源码文件: ${CLEANUP_SOURCE}"
echo "构建完，删除构建临时文件: ${CLEANUP_BUILD_TEMP}"
echo "===================================================="

printf "准备生成构建环境，确认信息无误后按 Enter 继续..."
read _

# 确定产物目录存在
mkdir -p "$OUTPUT_DIR"

# 生成 Debian 上游源码包 orig.tar.xz
ORIG_TARBALL="${OUTPUT_DIR}/${DEB_PACKAGE_NAME}_${PY_FULL_VERSION}.orig.tar.xz"
if [ ! -f "$ORIG_TARBALL" ]; then
    echo "生成 Debian 上游源码包 $ORIG_TARBALL"
    # 这里用 Python 源码文件生成 orig.tar.xz
    if [ ! -f "$PY_SRC" ]; then
        pwd
        echo "未找到 Python 源码文件，正在下载源码文件保存到：${PY_SRC}"
        wget "https://www.python.org/ftp/python/${PY_FULL_VERSION}/Python-${PY_FULL_VERSION}.tar.xz" \
            -O "$PY_SRC"
    fi
    cp "$PY_SRC" "$ORIG_TARBALL"
    echo "生成完成"
else
    echo "上游源码包 $ORIG_TARBALL 已存在"
fi

# 创建构建目录
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 解压 Python 源码
echo '正在解压 Python 源码文件'
tar -axf "$ORIG_TARBALL" \
    --strip-components=1 \
    -C "$BUILD_DIR"
echo '解压 Python 源码文件完成'


echo '初始化 Debian 打包骨架'
rm -rf "debian"
mkdir -p "debian"

echo '创建 debian/control'
cat > 'debian/control' << EOF
# 源码包
Source: ${DEB_PACKAGE_NAME}
Section: python
Priority: optional
Maintainer: ${GPG_UID}
Rules-Requires-Root: no
Build-Depends:
 debhelper-compat (= 13),
 build-essential,
 clang-19,
 pkg-config,
 libssl-dev,
 zlib1g-dev,
 libbz2-dev,
 liblzma-dev,
 libffi-dev,
 libreadline-dev,
 libsqlite3-dev,
 libncurses-dev,
 libgdbm-dev,
 libgdbm-compat-dev,
 libnss3-dev,
 uuid-dev,
 tk-dev,
 libzstd-dev,
Standards-Version: 4.6.2
Homepage: https://www.python.org/
#Vcs-Browser: https://salsa.debian.org/debian/${DEB_PACKAGE_NAME}
#Vcs-Git: https://salsa.debian.org/debian/${DEB_PACKAGE_NAME}.git

# 二进制包
Package: ${DEB_PACKAGE_NAME}
Architecture: ${ARCH}
Multi-Arch: same
Depends:
 \${shlibs:Depends},
 \${misc:Depends},
Description: Custom CPython ${PY_MAIN_VERSION} interpreter (${PACKAGER} build)
 Custom-built CPython ${PY_MAIN_VERSION} interpreter compiled by ${PACKAGER}.
 This package provides the python${PY_MAIN_VERSION} executable with
 a custom build configuration, separate from system Python.
EOF

echo '创建 debian/rules'
cat > 'debian/rules' <<  EOF
#!/usr/bin/make -f
# -*- makefile -*-

# 打印 dh 执行命令
#export DH_VERBOSE = 1
# 在编译和链接时 添加安全硬化选项
export DEB_BUILD_MAINT_OPTIONS = hardening=+all

%:
	dh \$@

override_dh_autoreconf:
	true

override_dh_auto_configure:
	./configure \\
$(printf '%s\n' "$CONFIGURE_ARGS" \
 | sed '$!s/$/ \\/' \
 | sed 's/^/\t\t/')
	# 修改 Python 编译信息
	if [ -f 'Makefile' ]; then \\
		sed -i 's/^GITVERSION=.*\$\$/GITVERSION=	echo ${PACKAGER}-build/' 'Makefile'; \\
		sed -i 's/^GITTAG=.*\$\$/GITTAG=		echo 小喾苦/' 'Makefile'; \\
		sed -i 's/^GITBRANCH=.*\$\$/GITBRANCH=	echo 小喾苦/' 'Makefile'; \\
	fi
EOF
chmod 0755 'debian/rules'

echo '创建 debian/changelog'
cat > 'debian/changelog' << EOF
${DEB_PACKAGE_NAME} (${DEB_PACKAGE_VERSION}) unstable; urgency=medium

  * Initial release.

 -- ${GPG_UID}  $(date -R)
EOF

mkdir -p 'debian/source'
echo '创建 debian/source/format'
cat > 'debian/source/format' << EOF
3.0 (quilt)
EOF

# 安装后执行
echo '创建 debian/postinst'
cat > 'debian/postinst' << EOF
#!/bin/sh
# postinst script for ${DEB_PACKAGE_NAME}.
#
# See: dh_installdeb(1).

set -e

# Summary of how this script can be called:
#        * <postinst> 'configure' <most-recently-configured-version>
#        * <old-postinst> 'abort-upgrade' <new version>
#        * <conflictor's-postinst> 'abort-remove' 'in-favour' <package>
#          <new-version>
#        * <postinst> 'abort-remove'
#        * <deconfigured's-postinst> 'abort-deconfigure' 'in-favour'
#          <failed-install-package> <version> 'removing'
#          <conflicting-package> <version>
# for details, see https://www.debian.org/doc/debian-policy/ or
# the debian-policy package.

SRC_DIR="${PREFIX}/bin"

case "\$1" in
    configure)
    # 安装软链接
    if [ ! -d "\$SRC_DIR" ]; then
            echo "postinst: \$SRC_DIR not found, skip"
            exit 0
        fi

        for f in "\$SRC_DIR"/*; do
            name=\$(basename "\$f")
            dst1="/usr/bin/\$name"
            dst2="/usr/bin/\${name}-${PACKAGER}"
            dst3="\$SRC_DIR/\${name}-${PACKAGER}"

            # 跳过非文件
            [ -f "\$f" ] || continue
            # 跳过链接
            [ -L "\$f" ] && continue
            # 跳过非可执行文件
            [ -x "\$f" ] || continue

            if [ ! -e "\$dst1" ]; then
                ln -s "\$f" "\$dst1"
                echo "postinst: linked \$dst1 -> \$f"
            else
                echo "postinst: exists, skip \$dst1"
            fi

            if [ ! -e "\$dst2" ]; then
                ln -s "\$f" "\$dst2"
                echo "postinst: linked \$dst2 -> \$f"
            else
                echo "postinst: exists, skip \$dst2"
            fi

            if [ ! -e "\$dst3" ]; then
                ln -s "\$f" "\$dst3"
                echo "postinst: linked \$dst3 -> \$f"
            else
                echo "postinst: exists, skip \$dst3"
            fi
        done
    ;;

    abort-upgrade|abort-remove|abort-deconfigure)
    ;;

    *)
        echo "postinst called with unknown argument '\$1'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
EOF
chmod 0755 'debian/postinst'

# 卸载前执行
echo '创建 debian/prerm'
cat > 'debian/prerm' << EOF
#!/bin/sh
# prerm script for ${DEB_PACKAGE_NAME}.
#
# See: dh_installdeb(1).

set -e

# Summary of how this script can be called:
#        * <prerm> 'remove'
#        * <old-prerm> 'upgrade' <new-version>
#        * <new-prerm> 'failed-upgrade' <old-version>
#        * <conflictor's-prerm> 'remove' 'in-favour' <package> <new-version>
#        * <deconfigured's-prerm> 'deconfigure' 'in-favour'
#          <package-being-installed> <version> 'removing'
#          <conflicting-package> <version>
# for details, see https://www.debian.org/doc/debian-policy/ or
# the debian-policy package.

SRC_DIR="${PREFIX}/bin"

case "\$1" in
    remove|upgrade|deconfigure)
    # 清理指向 -> \$SRC_DIR 的软链接
    # 1. 清理 /usr/bin 中 -> \$SRC_DIR/* 的链接
    for f in "/usr/bin"/*; do
        [ -L "\$f" ] || continue
        target=\$(readlink "\$f") || continue

        case "\$target" in
            "\$SRC_DIR"/*)
                rm -f "\$f"
                echo "prerm: removed \$f -> \$target"
                ;;
        esac
    done

    # 2. 清理 \$SRC_DIR 中包含 ${PACKAGER} 的链接文件 -> \$SRC_DIR/*
    if [ -d "\$SRC_DIR" ]; then
        for f in "\$SRC_DIR"/*${PACKAGER}*; do
            [ -L "\$f" ] || continue
            target=\$(readlink "\$f") || continue

            case "\$target" in
                "\$SRC_DIR"/*)
                    rm -f "\$f"
                    echo "prerm: removed \$f -> \$target"
                    ;;
            esac
        done
    fi
    ;;

    failed-upgrade)
    ;;

    *)
        echo "prerm called with unknown argument '\$1'" >&2
        exit 1
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
EOF
chmod 0755 'debian/prerm'


# 构建参数
DPKG_ARGS="--build=$BUILD_TYPE"

# 签名处理
if [ -n "$SIGN_KEY" ]; then
    echo "启用签名，GPG KEY = $SIGN_KEY"
    DPKG_ARGS="$DPKG_ARGS -k$SIGN_KEY"
else
    echo "不启用签名"
    DPKG_ARGS="$DPKG_ARGS -us -uc"
fi

# 执行构建
echo "构建命令: dpkg-buildpackage $DPKG_ARGS"

printf "构建环境生成完毕，按 Enter 开始构建 deb 包..."
read _

dpkg-buildpackage $DPKG_ARGS

# 前往构建产物目录——构建目录的上层目录
cd "$OUTPUT_DIR"

if [ "$CLEANUP_BUILD_TEMP" = "true" ]; then
    echo "正在清理构建临时文件"
    rm -rf "$BUILD_DIR"
    echo "清理完成"
fi

if [ "$CLEANUP_SOURCE" = "true" ]; then
    echo "正在清理源码"
    rm -rf "$PY_SRC"
    echo "清理完成"
fi

# 展示结果
pwd
ls -lh

echo "构建完成"
