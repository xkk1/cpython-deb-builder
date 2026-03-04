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

# 版本号
version='0.0.0'
# 配置文件
config_file=
# 帮助信息
usage=$(cat << EOF
用法：$0 [选项]
选项：
    -h, --help, --帮助      显示帮助信息
    -v, --version, --版本   显示版本信息
    -c, --config <文件>     指定配置文件
EOF
)
# 参数解析
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help|--帮助)
            printf '%s\n' "$usage"
            exit 0
            ;;
        -v|--version|--版本)
            printf 'v%s\n' "$version"
            exit 0
            ;;
        -c|--config)
            if [ -f "$2" ]; then
                . "$2"
                if [ -n "$config_file" ]; then
                    config_file="${config_file}:$2"
                else
                    config_file="$2"
                fi
            else
                printf '配置文件不存在: %s\n' "$2" >&2
                exit 1
            fi
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf '%s: %s: 无效的选项\n%s\n' "$0" "$1" "$usage" >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

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
# 是否启用 free-threaded (no GIL) 支持，关闭 'false' 启用 ‘true'
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
# 构建环境 deb 包名
buildenv_deb_package_name="${buildenv_deb_package_name:-${deb_package_name}-buildenv}"
# 构建环境 deb 包版本号
buildenv_deb_package_version="${buildenv_deb_package_version:-${py_full_version}}"
# 构建环境 构建目录，构建产物在构建目录的上层目录
buildenv_build_dir="${buildenv_build_dir:-$(pwd -P)/${buildenv_deb_package_name}}"


# 输出构建信息
echo "============ CPython Debian 自动打包脚本 ============"
printf '%s' "自动打包脚本: v${version}"
if [ -n "${config_file}" ]; then
    printf '\n%s\n' "配置文件: ${config_file}"
else
    printf '%s\n' "，使用默认配置"
fi
echo "Python 版本号: ${py_full_version}"
echo "deb 包名: ${deb_package_name}"
echo "deb 包架构: ${arch}"
echo "deb 包版本号: ${deb_package_version}"
echo "Maintainer: ${maintainer}"
echo "安装前缀: ${prefix}"
echo "构建目录: ${build_dir}"
# 产物目录（构建目录的上级）
output_dir="$(dirname "$build_dir")"
echo "产物目录: ${output_dir}"
echo "配置参数: ./configure \\"
printf '%s\n' "$(printf '%s\n' "$configure_args" \
 | sed '$!s/$/ \\/' \
 | sed 's/^/\t/')"
# 构建参数
dpkg_args="--build=$build_type"
echo "构建类型: dpkg-buildpackage --build=${build_type}"
if [ -n "$sign_key" ]; then
    echo "签名密钥: ${sign_key}"
    dpkg_args="$dpkg_args -k$sign_key"
else
    echo "不启用签名"
    dpkg_args="$dpkg_args -us -uc"
fi
echo "构建完，删除源码文件: ${cleanup_source}"
echo "构建完，删除构建临时文件: ${cleanup_build_temp}"
echo "===================================================="

# 记录当前工作目录为原始目录
original_dir=$(pwd)

printf '%s' "准备生成构建环境 deb 包 ${buildenv_deb_package_name}，请确认信息无误后按 Enter 继续..."
read _

# 创建构建目录
rm -rf "$buildenv_build_dir"
mkdir -p "$buildenv_build_dir"
cd "$buildenv_build_dir"
rm -rf "debian"
mkdir -p "debian"

echo '创建构建环境 deb 包 debian/control'
cat > 'debian/control' <<EOF
Source: ${buildenv_deb_package_name}
Section: devel
Priority: optional
Maintainer: ${maintainer}
Build-Depends: 
  debhelper-compat (= 13)
Standards-Version: 4.6.2
Rules-Requires-Root: no

Package: ${buildenv_deb_package_name}
Architecture: all
Depends:
 $(printf '%s' "$build_depends" \
 | tr ' ' '\n' \
 | sed '$!s/$/,/' \
 | sed 's/^/  /')
Description: Build environment for custom CPython (${packager})
 Meta package that installs all required development
 dependencies for building custom CPython.
EOF

echo '创建构建环境 deb 包 debian/changelog'
cat > debian/changelog <<EOF
${buildenv_deb_package_name} (${buildenv_deb_package_version}) unstable; urgency=medium

  * Initial release.

 -- ${maintainer}  $(date -R)
EOF

echo '创建构建环境 deb 包 debian/rules'
cat > debian/rules <<EOF
#!/usr/bin/make -f
%:
	dh \$@
EOF
chmod +x debian/rules

mkdir -p 'debian/source'
echo '创建构建环境 deb 包 debian/source/format'
cat > 'debian/source/format' <<EOF
3.0 (native)
EOF

echo "正在构建“构建环境 deb 包”"
dpkg-buildpackage -us -uc -b

cd "$original_dir"


printf '%s' "准备生成构建环境，确认信息无误后按 Enter 继续..."
read _

# 确定产物目录存在
mkdir -p "$output_dir"

# 生成 Debian 上游源码包 orig.tar.xz
orig_tarball="${output_dir}/${deb_package_name}_${py_full_version}.orig.tar.xz"
if [ ! -f "$orig_tarball" ]; then
    echo "生成 Debian 上游源码包 $orig_tarball"
    # 这里用 Python 源码文件生成 orig.tar.xz
    if [ ! -f "$PY_SRC" ]; then
        pwd
        echo "未找到 Python 源码文件，正在下载源码文件保存到：${PY_SRC}"
        wget "https://www.python.org/ftp/python/${py_full_version}/Python-${py_full_version}.tar.xz" \
            -O "$PY_SRC"
    fi
    cp "$PY_SRC" "$orig_tarball"
    echo "生成完成"
else
    echo "上游源码包 $orig_tarball 已存在"
fi

# 创建构建目录
rm -rf "$build_dir"
mkdir -p "$build_dir"
cd "$build_dir"

# 解压 Python 源码
echo '正在解压 Python 源码文件'
tar -axf "$orig_tarball" \
    --strip-components=1 \
    -C "$build_dir"
echo '解压 Python 源码文件完成'


echo '初始化 Debian 打包骨架'
rm -rf "debian"
mkdir -p "debian"

echo '创建 debian/control'
cat > 'debian/control' << EOF
# 源码包
Source: ${deb_package_name}
Section: python
Priority: optional
Maintainer: ${maintainer}
Rules-Requires-Root: no
Build-Depends:
 debhelper-compat (= 13),
$(printf '%s' "$build_depends" \
 | tr ' ' '\n' \
 | sed '$!s/$/,/' \
 | sed 's/^/  /')
Standards-Version: 4.6.2
Homepage: https://www.python.org/
#Vcs-Browser: https://salsa.debian.org/debian/${deb_package_name}
#Vcs-Git: https://salsa.debian.org/debian/${deb_package_name}.git

# 二进制包
Package: ${deb_package_name}
Architecture: ${arch}
Multi-Arch: same
Depends:
 \${shlibs:Depends},
 \${misc:Depends},
Description: Custom CPython ${py_main_version} interpreter (${packager} build)
 Custom-built CPython ${py_main_version} interpreter compiled by ${packager}.
 This package provides the python${py_main_version} executable with
 a custom build configuration, separate from system Python.
EOF

echo '创建 debian/rules'
escape_sed() {
    printf '%s' "$1" \
    | sed \
        -e 's/\\/\\\\/g' \
        -e 's/[\/&]/\\&/g' \
        -e 's/\$/$$$$/g' \
        -e "s/'/'\\\\''/g"
}
echo "GITVERSION=$GITVERSION"
echo "GITTAG=$GITTAG"
echo "GITBRANCH=$GITBRANCH"
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
$(printf '%s\n' "$configure_args" \
 | sed '$!s/$/ \\/' \
 | sed 's/^/\t\t/')
	# 修改 Python 编译信息
	if [ -f 'Makefile' ]; then \\
		sed -i 's/^GITVERSION=.*\$\$/GITVERSION=	$(escape_sed "$GITVERSION")/' 'Makefile'; \\
		sed -i 's/^GITTAG=.*\$\$/GITTAG=		$(escape_sed "$GITTAG")/' 'Makefile'; \\
		sed -i 's/^GITBRANCH=.*\$\$/GITBRANCH=	$(escape_sed "$GITBRANCH")/' 'Makefile'; \\
	fi
EOF
chmod 0755 'debian/rules'

echo '创建 debian/changelog'
cat > 'debian/changelog' << EOF
${deb_package_name} (${deb_package_version}) unstable; urgency=medium

  * Initial release.

 -- ${maintainer}  $(date -R)
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
# postinst script for ${deb_package_name}.
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

SRC_DIR="${prefix}/bin"

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
            dst2="/usr/bin/\${name}-${packager}"
            dst3="\$SRC_DIR/\${name}-${packager}"

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
# prerm script for ${deb_package_name}.
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

SRC_DIR="${prefix}/bin"

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

    # 2. 清理 \$SRC_DIR 中包含 ${packager} 的链接文件 -> \$SRC_DIR/*
    if [ -d "\$SRC_DIR" ]; then
        for f in "\$SRC_DIR"/*${packager}*; do
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

# 执行构建
echo "构建命令: dpkg-buildpackage $dpkg_args"

printf '%s' "构建环境生成完毕，按 Enter 开始构建 deb 包..."
read _

dpkg-buildpackage $dpkg_args

# 前往构建产物目录——构建目录的上层目录
cd "$output_dir"

if [ "$cleanup_build_temp" = "true" ]; then
    echo "正在清理构建临时文件"
    rm -rf "$build_dir"
    echo "清理完成"
fi

if [ "$cleanup_source" = "true" ]; then
    echo "正在清理源码"
    rm -rf "$PY_SRC"
    echo "清理完成"
fi

# 展示结果
pwd
ls -lh

cd "${original_dir}
echo "构建完成"
