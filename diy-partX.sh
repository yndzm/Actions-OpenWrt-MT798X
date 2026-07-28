#!/bin/bash

echo "=========================================="
echo "执行 diy-partX.sh (编译前最终配置注入)"
echo "=========================================="

# ---------------------------------------------------------
# 1. 终结 OpenClash / Ruby YJIT 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)

if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，物理剥离 Rust 依赖..."
    # 强制默认关闭 YJIT
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    # 剥离对 rust/host 的依赖（彻底斩断 Rust 编译）
    sed -i 's/+RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    # 全局关闭 yjit 编译选项
    sed -i 's/--enable-yjit/--disable-yjit/g' "$RUBY_MK"
    echo "✅ Ruby 对 Rust 的依赖已成功剥离！"
else
    echo "⚠️ 未找到 Ruby Makefile，跳过修改。"
fi

# ---------------------------------------------------------
# 2. 最终注入 .config 开关（保证在此之后不会再被 cp 覆盖）
# ---------------------------------------------------------
# 先清理可能存在的冲突选项
sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' .config 2>/dev/null || true

cat <<EOF >> .config
# 开启 daed / dae 及底层依赖
CONFIG_PACKAGE_luci-app-daede=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_vmlinux-btf=y

# 开启内核 BTF 顶层编译依赖
CONFIG_KERNEL_DEBUG_KERNEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_BPF_EVENTS=y

# 强制禁用 Ruby YJIT
# CONFIG_RUBY_ENABLE_YJIT is not set
EOF

echo "✅ 所有自定义 .config 配置已强行追加完成"

# ---------------------------------------------------------
# 3. 刷新并校验配置
# ---------------------------------------------------------
make defconfig

# ---------------------------------------------------------
# 3. 刷新并校验配置
# ---------------------------------------------------------
make defconfig
