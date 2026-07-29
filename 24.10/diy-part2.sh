#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "=========================================="
echo "执行自定义优化脚本 (diy-part2.sh)"
echo "=========================================="

# ---------------------------------------------------------
# 双重保险：终结 OpenClash 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
echo ">>> 开始执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."

# 方案 A：从配置文件强制取消 YJIT 编译
for conf in .config *.config; do
    if [ -f "$conf" ]; then
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
        echo "✅ 方案 A 成功：已在 $conf 中强制声明关闭 RUBY_ENABLE_YJIT"
    fi
done

# 方案 B：修改底层 Makefile，物理斩断 Rust 依赖
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)
if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，执行物理级依赖阉割..."
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK" 2>/dev/null || true
    echo "✅ 方案 B 成功：Ruby 对 Rust 的依赖链已被彻底斩断！"
else
    echo "⚠️ 警告: 未找到 Ruby 的 Makefile，方案 B 跳过。"
fi

# ---------------------------------------------------------
# 0. kenzok8/openwrt-daede 专项拉取与版本升级 (至 1.28.0)
# ---------------------------------------------------------
echo ">>> 正在处理 kenzok8/openwrt-daede 插件..."

# 清理旧的 daed 冲突包（保留 openwrt-daede 路径）
rm -rf feeds/packages/net/daed[cite: 2]
rm -rf feeds/luci/applications/luci-app-daed[cite: 2]
rm -rf package/feeds/packages/daed[cite: 2]
rm -rf package/feeds/luci/luci-app-daed[cite: 2]
rm -rf package/daed[cite: 2]
rm -rf package/luci-app-daed[cite: 2]

# 如果 package/ 目录下还没有 openwrt-daede，直接克隆 kenzok8 的仓库
if [ ! -d "package/openwrt-daede" ] && [ ! -d "package/luci-app-daede" ]; then
    echo ">>> 克隆 kenzok8/openwrt-daede 到 package/openwrt-daede..."
    git clone --depth 1 https://github.com/kenzok8/openwrt-daede.git package/openwrt-daede
fi

# 查找 daede/daed 的 Makefile 并强行修改版本号为 1.28.0
DAED_MAKEFILE=$(find package/ feeds/ -maxdepth 5 -path "*/daed*/Makefile" 2>/dev/null | head -n 1)

if [ -n "$DAED_MAKEFILE" ]; then
    echo "✅ 找到 Makefile: $DAED_MAKEFILE，正在强制升级至 1.28.0"
    sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.28.0/' "$DAED_MAKEFILE"[cite: 2]
    sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=v1.28.0/' "$DAED_MAKEFILE"[cite: 2]
    sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/' "$DAED_MAKEFILE"[cite: 2]
fi

# ---------------------------------------------------------
# libxcrypt 专项救治 (极致精简版)
# ---------------------------------------------------------
XCRYPT_MK="feeds/packages/libs/libxcrypt/Makefile"[cite: 2]
if [ -f "$XCRYPT_MK" ]; then[cite: 2]
    echo ">>> 正在硬化 libxcrypt 编译参数..."[cite: 2]
    sed -i 's/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /' "$XCRYPT_MK"[cite: 2]
    sed -i 's/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK"[cite: 2]
    echo "✅ libxcrypt 参数注入完成。"[cite: 2]
fi

# 5.1 Tailscale -> VPN 
TS_DIR=$(find feeds package -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)[cite: 2]
if [ -n "$TS_DIR" ]; then[cite: 2]
    echo ">>> 发现 Tailscale 插件目录: $TS_DIR"[cite: 2]
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g' {} +[cite: 2]
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +[cite: 2]
    echo "✅ Tailscale 菜单已移动到 VPN"[cite: 2]
fi

# 5.2 KSMBD -> NAS
KSMBD_DIR=$(find feeds/luci -type d -name "luci-app-ksmbd" | head -n 1)[cite: 2]
if [ -n "$KSMBD_DIR" ]; then[cite: 2]
    find "$KSMBD_DIR" -type f -exec sed -i 's|admin/services/ksmbd|admin/nas/ksmbd|g' {} +[cite: 2]
    find "$KSMBD_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +[cite: 2]
    echo "✅ KSMBD 菜单已移动"[cite: 2]
fi

# 5.3 OpenList2 -> NAS
OPENLIST2_DIR=$(find feeds package -type d -name "luci-app-openlist2" | head -n 1)[cite: 2]
if [ -n "$OPENLIST2_DIR" ]; then[cite: 2]
    find "$OPENLIST2_DIR" -type f -exec sed -i 's|admin/services/openlist2|admin/nas/openlist2|g' {} +[cite: 2]
    find "$OPENLIST2_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +[cite: 2]
    echo "✅ OpenList2 菜单已移动到 NAS"[cite: 2]
fi

# 修复Rust本地编译LLVM
RUST_FILE="feeds/packages/lang/rust/Makefile"[cite: 2]
if [ -f "$RUST_FILE" ]; then[cite: 2]
  sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$RUST_FILE"[cite: 2]
  echo "✅ Rust 已设置为本地编译 LLVM"[cite: 2]
fi

# =========================================================
# 网络参数优化（sysctl）
# =========================================================
mkdir -p files/etc/sysctl.d/[cite: 2]
cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'[cite: 2]
net.netfilter.nf_conntrack_max=32768[cite: 2]
net.netfilter.nf_conntrack_tcp_timeout_established=3600[cite: 2]
net.netfilter.nf_conntrack_udp_timeout=60[cite: 2]
net.netfilter.nf_conntrack_udp_timeout_stream=120[cite: 2]
net.core.netdev_max_backlog=2048[cite: 2]
net.core.somaxconn=2048[cite: 2]
net.ipv4.tcp_max_syn_backlog=2048[cite: 2]
net.ipv4.tcp_fastopen=3[cite: 2]
net.ipv4.tcp_slow_start_after_idle=0[cite: 2]
net.ipv4.tcp_tw_reuse=1[cite: 2]
net.ipv4.tcp_fin_timeout=30[cite: 2]
net.ipv4.tcp_keepalive_time=600[cite: 2]
net.ipv4.tcp_keepalive_intvl=15[cite: 2]
net.ipv4.tcp_keepalive_probes=5[cite: 2]
net.ipv4.tcp_max_tw_buckets=8192[cite: 2]
net.core.rmem_max=4194304[cite: 2]
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 131072 4194304[cite: 2]
net.ipv4.tcp_wmem=4096 65536 4194304[cite: 2]
net.ipv4.udp_mem=8192 12288 16384[cite: 2]
net.ipv4.ip_local_port_range=1024 65535[cite: 2]
SYSCTL
echo "✅ 网络优化参数已写入"[cite: 2]

# 修改默认 IP (192.168.2.1)
sed -i 's/192.168.6.1/192.168.2.1/g' package/base-files/files/bin/config_generate[cite: 2]

# Filogic (6.6 内核) 强行注入 BTF
find target/linux/mediatek/ -name "config-6.6" | while read -r kernel_config; do[cite: 2]
    sed -i '/CONFIG_DEBUG_INFO/d' "$kernel_config"[cite: 2]
    sed -i '/CONFIG_BPF/d' "$kernel_config"[cite: 2]
    cat <<EOF >> "$kernel_config"[cite: 2]
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
EOF[cite: 2]
done

# ---------------------------------------------------------
# 追加自定义 .config 参数并刷新依赖
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

# 刷新并补全依赖规则
make defconfig

echo "=========================================="
echo "自定义优化脚本执行完毕！"
echo "=========================================="
