#!/bin/bash

# ---------------------------------------------------------
# 双重保险：终结 OpenClash 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
echo ">>> 开始执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."

# ==========================================
# 方案 A：先从顶层配置文件强制取消 YJIT 编译
# ==========================================
# 遍历当前目录下的系统 .config 以及你仓库里的自定义 config (如 mt7986.config)
for conf in .config *.config; do
    if [ -f "$conf" ]; then
        # 1. 剔除可能存在的开启选项 (防冲突)
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        # 2. 强行追加关闭指令 (最高优先级)
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
        echo "✅ 方案 A 成功：已在 $conf 中强制声明关闭 RUBY_ENABLE_YJIT"
    fi
done

# ==========================================
# 方案 B：修改底层 Makefile，物理斩断依赖引擎
# ==========================================
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)

if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，执行物理级依赖阉割..."
    
    # 1. 防弹级正则破坏：在 config RUBY_ENABLE_YJIT 和 help 之间，将 default y 强制改为 default n
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    
    # 2. 釜底抽薪：精准删掉引发 Rust 编译的宿主机依赖关键词
    # sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    
    echo "✅ 方案 B 成功：Ruby 对 Rust 的依赖链已被彻底斩断！"
else
    echo "⚠️ 警告: 未找到 Ruby 的 Makefile，可能路径有变，方案 B 跳过。"
fi

echo "🎉 双重拦截部署完毕！"

echo "=========================================="
echo "执行 diy-partX.sh (编译前最终配置配置注入)"
echo "=========================================="

# ---------------------------------------------------------
# 1. 终结 OpenClash / Ruby YJIT 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)

if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，物理剥离 Rust 依赖..."
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    sed -i 's/+RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK"
    sed -i 's/--enable-yjit/--disable-yjit/g' "$RUBY_MK"
fi

# ---------------------------------------------------------
# 2. 最终注入 .config 开关（保证在此之后不会再被 cp 覆盖）
# ---------------------------------------------------------
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

# 禁用 Ruby YJIT
# CONFIG_RUBY_ENABLE_YJIT is not set
EOF

echo "✅ 所有自定义 .config 配置已强行追加完成"

# ---------------------------------------------------------
# 3. 刷新并校验配置
# ---------------------------------------------------------
make defconfig
