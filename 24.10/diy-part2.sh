#!/bin/bash
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "=========================================="
echo "执行自定义优化脚本 (diy-part2.sh)"
echo "=========================================="

# ---------------------------------------------------------
# 1. 解决 mihomo 递归依赖死锁 (recursive dependency detected)
# ---------------------------------------------------------
echo ">>> 正在排查并清理 mihomo 循环依赖包..."
find package/ feeds/ -type d -name "*mihomo*" 2>/dev/null | grep -E 'alpha|meta' | xargs rm -rf 2>/dev/null || true

# 清理遗留的不完整老版 luci-app-dae (避免 dae-geoip/geosite 警告)
find feeds/ package/ -type d -name "luci-app-dae" 2>/dev/null | xargs rm -rf 2>/dev/null || true

# ---------------------------------------------------------
# 2. 双重拦截：关闭 Ruby YJIT，跳过 rust/host 漫长编译
# ---------------------------------------------------------
echo ">>> 开始执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."

for conf in .config *.config; do
    if [ -f "$conf" ]; then
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
        echo "✅ 方案 A 成功：已在 $conf 中强制声明关闭 RUBY_ENABLE_YJIT"
    fi
done

RUBY_MK=$(find feeds package -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)
if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，执行物理级依赖阉割..."
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK" 2>/dev/null || true
    echo "✅ 方案 B 成功：Ruby 对 Rust 的依赖链已被彻底斩断！"
else
    echo "⚠️ 警告: 未找到 Ruby 的 Makefile，方案 B 跳过。"
fi

# ---------------------------------------------------------
# 3. kenzok8/openwrt-daede 专项拉取与版本升级 (至 1.28.0)
# ---------------------------------------------------------
echo ">>> 正在处理 kenzok8/openwrt-daede 插件..."

rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/daed
rm -rf package/feeds/luci/luci-app-daed
rm -rf package/daed
rm -rf package/luci-app-daed

if [ ! -d "package/openwrt-daede" ] && [ ! -d "package/custom/luci-app-daede" ]; then
    echo ">>> 克隆 kenzok8/openwrt-daede 到 package/openwrt-daede..."
    git clone --depth 1 https://github.com/kenzok8/openwrt-daede.git package/openwrt-daede
fi

DAED_MAKEFILE=$(find -L package/ feeds/ -maxdepth 5 -path "*/daed*/Makefile" -type f 2>/dev/null | head -n 1)
if [ -n "$DAED_MAKEFILE" ] && [ -f "$DAED_MAKEFILE" ]; then
    echo "✅ 找到 Makefile: $DAED_MAKEFILE，正在强制升级至 1.28.0"
    sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.28.0/' "$DAED_MAKEFILE"
    sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=v1.28.0/' "$DAED_MAKEFILE"
    sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/' "$DAED_MAKEFILE"
fi

# ---------------------------------------------------------
# 4. libxcrypt 专项救治
# ---------------------------------------------------------
XCRYPT_MK=$(find feeds package -name "Makefile" -path "*/libxcrypt/Makefile" 2>/dev/null | head -n 1)
if [ -n "$XCRYPT_MK" ] && [ -f "$XCRYPT_MK" ]; then
    echo ">>> 正在硬化 libxcrypt 编译参数..."
    sed -i 's/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /' "$XCRYPT_MK"
    sed -i 's/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK"
    echo "✅ libxcrypt 参数注入完成。"
fi

# ---------------------------------------------------------
# 5. 菜单归类调整
# ---------------------------------------------------------
# 5.1 Tailscale -> VPN
TS_DIR=$(find feeds package -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)
if [ -n "$TS_DIR" ]; then
    echo ">>> 发现 Tailscale 插件目录: $TS_DIR"
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g' {} +
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +
    echo "✅ Tailscale 菜单已移动到 VPN"
fi

# 5.2 KSMBD -> NAS
KSMBD_DIR=$(find feeds package -type d -name "luci-app-ksmbd" 2>/dev/null | head -n 1)
if [ -n "$KSMBD_DIR" ]; then
    find "$KSMBD_DIR" -type f -exec sed -i 's|admin/services/ksmbd|admin/nas/ksmbd|g' {} +
    find "$KSMBD_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ KSMBD 菜单已移动"
fi

# 5.3 OpenList2 -> NAS
OPENLIST2_DIR=$(find feeds package -type d -name "luci-app-openlist2" 2>/dev/null | head -n 1)
if [ -n "$OPENLIST2_DIR" ]; then
    find "$OPENLIST2_DIR" -type f -exec sed -i 's|admin/services/openlist2|admin/nas/openlist2|g' {} +
    find "$OPENLIST2_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ OpenList2 菜单已移动到 NAS"
fi

# 修复 Rust 本地编译 LLVM
RUST_FILE=$(find feeds package -name "Makefile" -path "*/lang/rust/Makefile" 2>/dev/null | head -n 1)
if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$RUST_FILE"
    echo "✅ Rust 已设置为本地编译 LLVM"
fi

# ---------------------------------------------------------
# 6. 系统参数与网络优化（sysctl）
# ---------------------------------------------------------
mkdir -p files/etc/sysctl.d/
cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
net.netfilter.nf_conntrack_max=32768
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.udp_mem=8192 12288 16384
net.ipv4.ip_local_port_range=1024 65535
SYSCTL
echo "✅ 网络优化参数已写入"

# 修改管理后台默认 IP (192.168.2.1)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# ---------------------------------------------------------
# 7. Filogic (6.6 内核) 强行注入 BTF
# ---------------------------------------------------------
find target/linux/mediatek/ -name "config-6.6" 2>/dev/null | while read -r kernel_config; do
    sed -i '/CONFIG_DEBUG_INFO/d' "$kernel_config"
    sed -i '/CONFIG_BPF/d' "$kernel_config"
    cat <<EOF >> "$kernel_config"
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_EVENTS=y
CONFIG_NET_ACT_BPF=y
CONFIG_NET_CLS_ACT=y
CONFIG_CGROUP_BPF=y
EOF
done

# ---------------------------------------------------------
# 9. 追加自定义 .config 参数并单次刷新依赖
# ---------------------------------------------------------
echo ">>> 正在追加自定义 .config 配置..."
cat <<EOF >> .config
# 开启 kenzok8/openwrt-daede (luci-app-daede) 及相关依赖
CONFIG_PACKAGE_luci-app-daede=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_vmlinux-btf=y

# 开启内核 BTF 顶层编译依赖
CONFIG_KERNEL_DEBUG_KERNEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_BPF_EVENTS=y

# 禁用 Ruby YJIT
# CONFIG_RUBY_ENABLE_YJIT is not set
EOF

echo "✅ 所有自定义 .config 配置已强行追加完成"

# 刷新并生成最终依赖树
make defconfig

echo "=========================================="
echo "自定义优化脚本执行完毕！"
echo "=========================================="
