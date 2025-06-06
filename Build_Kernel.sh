#!/bin/bash

# 颜色定义
info() {
  tput setaf 3  
  echo "[INFO] $1"
  tput sgr0
}

error() {
  tput setaf 1
  echo "[ERROR] $1"
  tput sgr0
  exit 1
}

# 参数设置
KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
ENABLE_KPM=true
ENABLE_LZ4KD=true

# 机型选择
info "请选择要编译的机型："
info "1. 一加 Ace 5 Pro"
info "2. 一加 13"
info "3.一加 13T"
read -p "输入选择 [1-3]: " device_choice

case $device_choice in
    1)
        DEVICE_NAME="oneplus_ace5_pro"
        REPO_MANIFEST="JiuGeFaCai_oneplus_ace5_pro_v.xml"
        KERNEL_TIME="Wed Dec 4 02:11:46 UTC 2024"
        ;;
    2)
        DEVICE_NAME="oneplus_13"
        REPO_MANIFEST="JiuGeFaCai_oneplus_13_v.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        ;;
    3)
        DEVICE_NAME="oneplus_13t"
        REPO_MANIFEST="oneplus_13t.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        ;;
    *)
        error "无效的选择，请输入1-3之间的数字"
        ;;
esac

# 自定义补丁
read -p "输入内核名称修改(可改中文和emoji) [回车默认官核名称]: " input_suffix
[ -n "$input_suffix" ] && KERNEL_SUFFIX="$input_suffix"

read -p "输入内核构建日期更改(回车默认为原厂) : " input_time
[ -n "$input_time" ] && KERNEL_TIME="$input_time"

read -p "是否启用kpm?(回车默认开启) [y/N]: " kpm
[[ "$kpm" =~ [yY] ]] && ENABLE_KPM=true

read -p "是否启用lz4kd?(回车默认开启) [y/N]: " lz4
[[ "$lz4" =~ [yY] ]] && ENABLE_LZ4KD=true

# SukiSu分支选择
info "请选择要编译的SukiSu分支："
info "1. Stable分支(稳定版分支)"
info "2. dev分支(测试版分支)"
read -p "输入选择 [1-2]: " branch_choice
case $branch_choice in
    1)
        SUKI_BRANCH="stable"
        ;;
    2)
        SUKI_BRANCH="dev"
        ;;
    *)
        error "无效的选择，请输入1或2"
        ;;
esac

# 环境变量 - 按机型区分ccache目录
export CCACHE_COMPILERCHECK="%compiler% -dumpmachine; %compiler% -dumpversion"
export CCACHE_NOHASHDIR="true"
export CCACHE_HARDLINK="true"
export CCACHE_DIR="$HOME/.ccache_${DEVICE_NAME}"  # 改为按机型区分
export CCACHE_MAXSIZE="8G"

# ccache 初始化标志文件也按机型区分
CCACHE_INIT_FLAG="$CCACHE_DIR/.ccache_initialized"

# 初始化 ccache（仅第一次）
if command -v ccache >/dev/null 2>&1; then
    if [ ! -f "$CCACHE_INIT_FLAG" ]; then
        info "第一次为${DEVICE_NAME}初始化ccache..."
        mkdir -p "$CCACHE_DIR" || error "无法创建ccache目录"
        ccache -M "$CCACHE_MAXSIZE"
        touch "$CCACHE_INIT_FLAG"
    else
        info "ccache (${DEVICE_NAME}) 已初始化，跳过..."
    fi
else
    info "未安装 ccache，跳过初始化"
fi

# 工作目录 - 按机型区分
WORKSPACE="$HOME/kernel_${DEVICE_NAME}"
mkdir -p "$WORKSPACE" || error "无法创建工作目录"
cd "$WORKSPACE" || error "无法进入工作目录"

# 检查并安装依赖
info "检查并安装依赖..."
DEPS=(python3 git curl ccache flex bison libssl-dev libelf-dev bc)
MISSING_DEPS=()

for pkg in "${DEPS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_DEPS+=("$pkg")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    info "所有依赖已安装，跳过安装。"
else
    info "缺少依赖：${MISSING_DEPS[*]}，正在安装..."
    sudo apt update || error "系统更新失败"
    sudo apt install -y "${MISSING_DEPS[@]}" || error "依赖安装失败"
fi

# 配置 Git（仅在未配置时）
info "检查 Git 配置..."

GIT_NAME=$(git config --global user.name || echo "")
GIT_EMAIL=$(git config --global user.email || echo "")

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    info "Git 未配置，正在设置..."
    git config --global user.name "Q1udaoyu"
    git config --global user.email "sucisama2888@gmail.com"
else
    info "Git 已配置："
fi

# 安装repo工具（仅首次）
if ! command -v repo >/dev/null 2>&1; then
    info "安装repo工具..."
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo > ~/repo || error "repo下载失败"
    chmod a+x ~/repo
    sudo mv ~/repo /usr/local/bin/repo || error "repo安装失败"
else
    info "repo工具已安装，跳过安装"
fi

# ==================== 源码管理 ====================

# 创建源码目录
KERNEL_WORKSPACE="$WORKSPACE/kernel_workspace"

mkdir -p "$KERNEL_WORKSPACE" || error "无法创建kernel_workspace目录"

cd "$KERNEL_WORKSPACE" || error "无法进入kernel_workspace目录"

# 初始化源码
info "初始化repo并同步源码..."
repo init -u https://github.com/HanKuCha/kernel_manifest.git -b refs/heads/oneplus/sm8750 -m "$REPO_MANIFEST" --depth=1 || error "repo初始化失败"
repo --trace sync -c -j$(nproc --all) --no-tags || error "repo同步失败"

# ==================== 核心构建步骤 ====================

# 清理保护导出
info "清理保护导出文件..."
rm -f kernel_platform/common/android/abi_gki_protected_exports_*
rm -f kernel_platform/msm-kernel/android/abi_gki_protected_exports_*

# 设置SukiSU
info "设置SukiSU..."
cd kernel_platform || error "进入kernel_platform失败"
curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-${SUKI_BRANCH} || error "SukiSU设置失败"

cd KernelSU || error "进入KernelSU目录失败"
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count main) "+" 10606)
export KSU_VERSION=$KSU_VERSION
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile || error "修改KernelSU版本失败"

# 设置susfs
info "设置susfs..."
cd "$KERNEL_WORKSPACE" || error "返回工作目录失败"
git clone -q https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6 || info "susfs4ksu已存在或克隆失败"
git clone -q https://github.com/ShirkNeko/SukiSU_patch.git || info "SukiSU_patch已存在或克隆失败"

cd kernel_platform || error "进入kernel_platform失败"
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

# 复制lz4k文件
cp -r ../SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux
cp -r ../SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
cp -r ../SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
cp -r ../SukiSU_patch/other/zram/lz4k_oplus ./common/lib/

cd $KERNEL_WORKSPACE/kernel_platform/common || { echo "进入common目录失败"; exit 1; }


# 判断当前编译机型是否为一加13t
if [ "$DEVICE_NAME" = "oneplus_13t" ]; then
    info "当前编译机型为一加13T, 跳过patch补丁应用"
else
    info "DEVICE_NAME is $DEVICE_NAME, 正在应用patch补丁..."
    
    # 应用补丁

    sed -i 's/-32,12 +32,38/-32,11 +32,37/g' 50_add_susfs_in_gki-android15-6.6.patch
    sed -i '/#include <trace\/hooks\/fs.h>/d' 50_add_susfs_in_gki-android15-6.6.patch
fi

patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || info "SUSFS补丁应用可能有警告"
cp "$KERNEL_WORKSPACE/SukiSU_patch/hooks/syscall_hooks.patch" ./ || error "复制syscall_hooks.patch失败"
patch -p1 -F 3 < syscall_hooks.patch || info "syscall_hooks补丁应用可能有警告"

# 应用HMBird GKI补丁
info "应用HMBird GKI补丁..."
cd drivers || error "进入drivers目录失败"
cat << 'EOF' > hmbird_patch.c
#include <linux/init.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/slab.h>
#include <linux/string.h>

static int __init hmbird_patch_init(void)
{
    struct device_node *ver_np;
    const char *type;
    int ret;

    ver_np = of_find_node_by_path("/soc/oplus,hmbird/version_type");
    if (!ver_np) {
         pr_info("hmbird_patch: version_type node not found\n");
         return 0;
    }

    ret = of_property_read_string(ver_np, "type", &type);
    if (ret) {
         pr_info("hmbird_patch: type property not found\n");
         of_node_put(ver_np);
         return 0;
    }

    if (strcmp(type, "HMBIRD_OGKI")) {
         of_node_put(ver_np);
         return 0;
    }

    struct property *prop = of_find_property(ver_np, "type", NULL);
    if (prop) {
         struct property *new_prop = kmalloc(sizeof(*prop), GFP_KERNEL);
         if (!new_prop) {
              pr_info("hmbird_patch: kmalloc for new_prop failed\n");
              of_node_put(ver_np);
              return 0;
         }
         memcpy(new_prop, prop, sizeof(*prop));
         new_prop->value = kmalloc(strlen("HMBIRD_GKI") + 1, GFP_KERNEL);
         if (!new_prop->value) {
              pr_info("hmbird_patch: kmalloc for new_prop->value failed\n");
              kfree(new_prop);
              of_node_put(ver_np);
              return 0;
         }
         strcpy(new_prop->value, "HMBIRD_GKI");
         new_prop->length = strlen("HMBIRD_GKI") + 1;

         if (of_remove_property(ver_np, prop) != 0) {
              pr_info("hmbird_patch: of_remove_property failed\n");
              return 0;
         }
         if (of_add_property(ver_np, new_prop) !=0) {
              pr_info("hmbird_patch: of_add_property failed\n");
              return 0;
         }
         pr_info("hmbird_patch: success from HMBIRD_OGKI to HMBIRD_GKI\n");
    }
    else {
         pr_info("hmbird_patch: type property structure not found\n");
    }
    of_node_put(ver_np);
    return 0;
}
early_initcall(hmbird_patch_init);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("reigadegr");
MODULE_DESCRIPTION("Forcefully convert HMBIRD_OGKI to HMBIRD_GKI.");
EOF

if ! grep -q "hmbird_patch.o" Makefile; then
    echo "obj-y += hmbird_patch.o" >> Makefile
fi

# 返回common目录
cd .. || error "返回common目录失败"

# 应用lz4kd补丁
if [ "$ENABLE_LZ4KD" = true ]; then
    info "应用lz4kd补丁..."
    # 使用绝对路径确保正确找到补丁文件
    cp "$KERNEL_WORKSPACE/SukiSU_patch/other/zram/zram_patch/6.6/lz4kd.patch" ./ || error "复制lz4kd补丁失败"
    patch -p1 -F 3 < lz4kd.patch || info "lz4kd补丁应用可能有警告"
fi

# 添加SUSFS配置
info "添加SUSFS配置..."
cd arch/arm64/configs || error "进入configs目录失败"
echo -e "CONFIG_KSU=y
CONFIG_KSU_SUSFS_SUS_SU=n
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_LOCALVERSION_AUTO=n" >> gki_defconfig

# 返回kernel_platform目录
cd $KERNEL_WORKSPACE/kernel_platform || error "返回kernel_platform目录失败"

# 移除check_defconfig
sudo sed -i 's/check_defconfig//' $KERNEL_WORKSPACE/kernel_platform/common/build.config.gki || error "修改build.config.gki失败"

# 添加KPM配置
if [ "$ENABLE_KPM" = true ]; then
    info "添加KPM配置..."
    echo "CONFIG_KPM=y" >> common/arch/arm64/configs/gki_defconfig
    sudo sed -i 's/check_defconfig//' common/build.config.gki || error "修改build.config.gki失败"
fi

# 修改内核名称
info "修改内核名称..."
sed -i 's/${scm_version}//' common/scripts/setlocalversion || error "修改setlocalversion失败"
sudo sed -i "s/-4k/${KERNEL_SUFFIX}/g" common/arch/arm64/configs/gki_defconfig || error "修改gki_defconfig失败"

# 构建内核
info "开始构建内核..."
export KBUILD_BUILD_TIMESTAMP="$KERNEL_TIME"
export PATH="$KERNEL_WORKSPACE/kernel_platform/prebuilts/clang/host/linux-x86/clang-r510928/bin:$PATH"
export PATH="/usr/lib/ccache:$PATH"

cd common || error "进入common目录失败"
# 判断当前编译机型是否为一加13t
if [ "$DEVICE_NAME" = "oneplus_13t" ]; then
    info "当前编译机型为一加13T，KCFLAGS参数跳过-O2"
    make -j$(nproc --all) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang \
    RUSTC=../../prebuilts/rust/linux-x86/1.73.0b/bin/rustc \
    PAHOLE=../../prebuilts/kernel-build-tools/linux-x86/bin/pahole \
    LD=ld.lld HOSTLD=ld.lld O=out gki_defconfig all || error "内核构建失败"
else
    info "当前编译机型为非一加13T，KCFLAGS参数加入-O2以提升生成代码的性能"
    make -j$(nproc --all) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang \
    RUSTC=../../prebuilts/rust/linux-x86/1.73.0b/bin/rustc \
    PAHOLE=../../prebuilts/kernel-build-tools/linux-x86/bin/pahole \
    LD=ld.lld HOSTLD=ld.lld O=out KCFLAGS+=-O2 gki_defconfig all \
    || error "内核构建失败"

fi

# 应用Linux补丁
info "应用Linux补丁..."
cd out/arch/arm64/boot || error "进入boot目录失败"
curl -LO https://github.com/ShirkNeko/SukiSU_KernelPatch_patch/releases/download/0.11-beta/patch_linux || error "下载patch_linux失败"
chmod +x patch_linux
./patch_linux || error "应用patch_linux失败"
rm -f Image
mv oImage Image || error "重命名Image失败"

# 创建AnyKernel3包
info "创建AnyKernel3包..."
cd "$WORKSPACE" || error "返回工作目录失败"
git clone -q https://github.com/Kernel-SU/AnyKernel3.git --depth=1 || info "AnyKernel3已存在"
rm -rf ./AnyKernel3/.git
rm -f ./AnyKernel3/push.sh
cp "$KERNEL_WORKSPACE/kernel_platform/common/out/arch/arm64/boot/Image" ./AnyKernel3/ || error "复制Image失败"

# 打包
cd AnyKernel3 || error "进入AnyKernel3目录失败"
zip -r "../AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu.zip" ./* || error "打包失败"

# 创建C盘输出目录（通过WSL访问Windows的C盘）
WIN_OUTPUT_DIR="/mnt/c/Kernel_Build/${DEVICE_NAME}/"
mkdir -p "$WIN_OUTPUT_DIR" || info "无法创建Windows目录，可能未挂载C盘，将保存到Linux目录"

# 复制Image和AnyKernel3包
cp "$KERNEL_WORKSPACE/kernel_platform/common/out/arch/arm64/boot/Image" "$WIN_OUTPUT_DIR/"
cp "$WORKSPACE/AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu_${SUKI_BRANCH}.zip" "$WIN_OUTPUT_DIR/"

info "内核包路径: C:/Kernel_Build/${DEVICE_NAME}/AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu_${SUKI_BRANCH}.zip.zip"
info "Image路径: C:/Kernel_Build/${DEVICE_NAME}/Image"
info "请在C盘目录中查找内核包和Image文件。"
info "清理本次构建的所有文件..."
sudo rm -rf "$WORKSPACE/kernel_workspace" || info "无法删除工作目录，可能未创建"
info "清理完成！下次运行脚本将重新拉取源码并构建内核。"
