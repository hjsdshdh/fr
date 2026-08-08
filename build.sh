#!/bin/bash
set -e
set -x

echo "
###############################
# 努比亚z60 ultra内核编译脚本 #
###############################"

# KernelSU原版
kernelsu_office() {
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
	[[ "${SUSFS_STAT}" =~ ^[yY]$ ]] && patch -p1 -F3 -d ${KERNEL_DIR}/KernelSU < ${HOME}/android_kernel/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch
	KSU_BRANCH="-KernelSU"
}
# kernelSU-Next
kernelsu_next() {
	if [[ "${SUSFS_STAT}" =~ ^[yY]$ ]]; then
		curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
	else
		curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s dev
	fi
	KSU_BRANCH="-KernelSU_Next"
}
# SukiSU Ultra
sukisu_ultra() {
	if [[ "${SUSFS_STAT}" =~ ^[yY]$ ]]; then
		curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin
	else
		curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s main
	fi
	KSU_BRANCH="-SukiSU_Ultra"
}
# ReSukiSU
resukisu() {
	curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
	KSU_BRANCH="-ReSukiSU"
}

# 为内核打入SuSFS补丁
susfs_patch() {
	cp -r ${HOME}/android_kernel/susfs4ksu/kernel_patches/fs ${KERNEL_DIR}
	cp -r ${HOME}/android_kernel/susfs4ksu/kernel_patches/include ${KERNEL_DIR}
	patch -p1 -F3 -d ${KERNEL_DIR} < ${HOME}/android_kernel/susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch
}
next_susfs_patch() {
	cp -r ${HOME}/android_kernel/ps_susfs4ksu/kernel_patches/fs ${KERNEL_DIR}
	cp -r ${HOME}/android_kernel/ps_susfs4ksu/kernel_patches/include ${KERNEL_DIR}
	patch -p1 -F3 -d ${KERNEL_DIR} < ${HOME}/android_kernel/ps_susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch
}
update_susfs() {
	if [ -d "${HOME}/android_kernel/susfs4ksu/.git" ]; then
		cd ${HOME}/android_kernel/susfs4ksu
		git fetch --all
		git reset --hard origin/gki-android14-6.1-dev
		git pull
	else
		git clone https://gitlab.com/pershoot/susfs4ksu.git -b gki-android14-6.1-dev --depth=1 ${HOME}/android_kernel/susfs4ksu
	fi
}
update_nextsusfs() {
	if [ -d "${HOME}/android_kernel/ps_susfs4ksu/.git" ]; then
		cd ${HOME}/android_kernel/ps_susfs4ksu
		git fetch --all
		git reset --hard origin/gki-android14-6.1-dev
		git pull
	else
		git clone https://gitlab.com/pershoot/susfs4ksu/ -b gki-android14-6.1-dev --depth=1 ${HOME}/android_kernel/ps_susfs4ksu
	fi
}

# 固定选择 ReSukiSU + 全部功能
KERNELSU_TAG=4
SUSFS_STAT=y
NET_STAT=y
BBR_STAT=y
MFY_STAT=y
DS_STAT=y
SSG_STAT=y
BBG_STAT=y

export PATH=${HOME}/android_kernel/build-tools/llvm22/bin:${PATH}
export KERNEL_DIR=${HOME}/android_kernel/android_nx721j_kernel
export OUT_DIR=${HOME}/android_kernel/nx721j_out
export DEFCONFIG_FILE=${KERNEL_DIR}/arch/arm64/configs/nx721j_defconfig
export LC_ALL=C
export KMI_GENERATION=11
export BRANCH=android14-6.1
export KBUILD_BUILD_USER="xiaoxian"
export KBUILD_BUILD_HOST="fedora"
export BUILD_NUMBER="11695701"
export KBUILD_BUILD_TIMESTAMP="Wed Apr 10 08:51:29 UTC 2024"
export KBUILD_BUILD_VERSION=1

mkdir -p ${HOME}/android_kernel

# 内核源码
[ ! -d "${KERNEL_DIR}" ] && git clone https://github.com/xiaoxian8/android_nx721j_kernel.git -b myos14.5 --depth=1 ${KERNEL_DIR}

# LLVM 工具链（修复：先创建父目录，再移动）
[ ! -d "${HOME}/android_kernel/build-tools/llvm22" ] && {
    mkdir -p ${HOME}/android_kernel/build-tools   # 确保父目录存在
    wget -P ${HOME}/ https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-Linux-X64.tar.xz
    tar -xvf ${HOME}/LLVM-22.1.8-Linux-X64.tar.xz -C ${HOME}
    # 兼容大小写
    if [ -d "${HOME}/LLVM-22.1.8-Linux-X64" ]; then
        mv ${HOME}/LLVM-22.1.8-Linux-X64 ${HOME}/android_kernel/build-tools/llvm22
    elif [ -d "${HOME}/LLVM-22.1.8-Linux-x64" ]; then
        mv ${HOME}/LLVM-22.1.8-Linux-x64 ${HOME}/android_kernel/build-tools/llvm22
    else
        echo "错误：解压后的LLVM目录未找到！"
        ls -l ${HOME}
        exit 1
    fi
}

# AnyKernel3
[ ! -d "${HOME}/android_kernel/AnyKernel3" ] && git clone https://github.com/Kernel-SU/AnyKernel3.git --depth=1 ${HOME}/android_kernel/AnyKernel3

cd ${KERNEL_DIR}
git checkout --ours .
rm -f ${KERNEL_DIR}/drivers/kernelsu
rm -rf ${KERNEL_DIR}/KernelSU
rm -rf ${KERNEL_DIR}/KernelSU-Next
find . -name "*.rej" -delete
find . -name "*.orig" -delete

./scripts/kconfig/merge_config.sh -m \
    arch/arm64/configs/gki_defconfig \
    arch/arm64/configs/vendor/pineapple_GKI.config \
    arch/arm64/configs/oem/pineapple_diff_config \
    arch/arm64/configs/oem/zlog_diff_config \
    arch/arm64/configs/oem/boards/cerro_diff_config
mv .config ${DEFCONFIG_FILE}
sed -i 's/ -dirty//g' "${KERNEL_DIR}/scripts/setlocalversion"

case ${KERNELSU_TAG} in
	1|3|4)
		[[ "${SUSFS_STAT}" =~ ^[yY]$ ]] && update_susfs && susfs_patch
		cd ${KERNEL_DIR}
		[[ "${KERNELSU_TAG}" == "1" ]] && kernelsu_office
		[[ "${KERNELSU_TAG}" == "3" ]] && sukisu_ultra
		[[ "${KERNELSU_TAG}" == "4" ]] && resukisu
		;;
	2)
		[[ "${SUSFS_STAT}" =~ ^[yY]$ ]] && update_nextsusfs && next_susfs_patch
		cd ${KERNEL_DIR}
		kernelsu_next
		;;
esac

case ${KERNELSU_TAG} in
	1|2|3|4)
		if [ -d KernelSU ]; then
			cd ${KERNEL_DIR}/KernelSU
		elif [ -d KernelSU-Next ]; then
			cd ${KERNEL_DIR}/KernelSU-Next
		fi
		if [[ "${KERNELSU_TAG}" =~ ^[12]$ ]]; then
			KSU_VERSION=_$(expr 30000 + $(git rev-list --count remotes/origin/HEAD 2>/dev/null || echo 0))
		fi
		if [[ "${KERNELSU_TAG}" == "3" ]]; then
			KSU_VERSION=_$(expr 40000 - 2815 + $(git rev-list --count remotes/origin/HEAD 2>/dev/null || echo 0))
		fi
		if [[ "${KERNELSU_TAG}" == "4" ]]; then
			KSU_VERSION=_$(expr 30000 + 700 + $(git rev-list --count remotes/origin/HEAD 2>/dev/null || echo 0))
		fi
		cd ${KERNEL_DIR}
		cat>>${DEFCONFIG_FILE}<<EOF
CONFIG_KSU=y
CONFIG_KSU_THRONE_TRACKER_ALWAYS_THREADED=n
EOF
		if [[ "${SUSFS_STAT}" =~ ^[yY]$ ]]; then
			SUSFS_V="-SuSFS"
			cat>>${DEFCONFIG_FILE}<<EOF
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
EOF
		fi
esac

# SSG
if [[ "${SSG_STAT}" =~ ^[yY]$ ]]; then
	SSG_V="+SSG"
	[ ! -d "${HOME}/android_kernel/ssg_patch" ] && git clone https://github.com/xiaoxian8/ssg_patch.git --depth=1 ${HOME}/android_kernel/ssg_patch
	cp -r ${HOME}/android_kernel/ssg_patch/block ${KERNEL_DIR}
	patch -p1 -d ${KERNEL_DIR} < ${HOME}/android_kernel/ssg_patch/ssg.patch
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_MQ_IOSCHED_SSG=y
CONFIG_MQ_IOSCHED_SSG_CGROUP=y
EOF
fi

# BBG
if [[ "${BBG_STAT}" =~ ^[yY]$ ]]; then
	BBG_V="+BBG"
	wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
	cat>>${DEFCONFIG_FILE}<<EOF
CONFIG_BBG=y
CONFIG_BBG_BLOCK_RECOVERY=y
CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"
EOF
fi

# BBR
if [[ "${BBR_STAT}" =~ ^[yY]$ ]]; then
	BBR_V="+BBR"
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_NET_SCH_FQ=y
CONFIG_TCP_CONG_BIC=n
CONFIG_TCP_CONG_WESTWOOD=n
CONFIG_TCP_CONG_HTCP=n
EOF
fi

# Mountify
if [[ "${MFY_STAT}" =~ ^[yY]$ ]]; then
	MFY_V="+Mountify"
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y
EOF
fi

# Netfilter
if [[ "${NET_STAT}" =~ ^[yY]$ ]]; then
	NET_V="+Netfilter+IPSET"
	cat>>${DEFCONFIG_FILE}<<EOF
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_IP_SET=y
CONFIG_IP_SET_MAX=65534
CONFIG_IP_SET_BITMAP_IP=y
CONFIG_IP_SET_BITMAP_IPMAC=y
CONFIG_IP_SET_BITMAP_PORT=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_IPMARK=y
CONFIG_IP_SET_HASH_IPPORT=y
CONFIG_IP_SET_HASH_IPPORTIP=y
CONFIG_IP_SET_HASH_IPPORTNET=y
CONFIG_IP_SET_HASH_IPMAC=y
CONFIG_IP_SET_HASH_MAC=y
CONFIG_IP_SET_HASH_NETPORTNET=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_IP_SET_HASH_NETNET=y
CONFIG_IP_SET_HASH_NETPORT=y
CONFIG_IP_SET_LIST_SET=y
EOF
fi

# Droidspaces
if [[ "${DS_STAT}" =~ ^[yY]$ ]]; then
	export DDP_V="+Droidspaces"
	[ ! -f "${KERNEL_DIR}/001.GKI-below-6.12-fix_sysvipc_kabi_3_4_5.patch" ] && wget https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/refs/heads/main/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_3_4_5.patch
	patch -p1 -d ${KERNEL_DIR} < 001.GKI-below-6.12-fix_sysvipc_kabi_3_4_5.patch
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
CONFIG_DEVTMPFS=y
CONFIG_NETFILTER_XT_TARGET_REJECT=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
EOF
fi

if [[ "${DS_STAT}" =~ ^[yY]$ && ! "${NET_STAT}" =~ ^[yY]$ ]]; then
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_IP_SET=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_NETFILTER_XT_SET=y
EOF
fi

if [[ "${DS_STAT}" =~ ^[yY]$ && ! "${MFY_STAT}" =~ ^[yY]$ ]]; then
	cat >>${DEFCONFIG_FILE}<<EOF
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y
EOF
fi

args="-j$(nproc --all) \
    O=${OUT_DIR} \
    -C ${KERNEL_DIR} \
    ARCH=arm64 \
    LLVM=1 \
    DEPMOD=depmod \
    DTC=/usr/bin/dtc"

make ${args} nx721j_defconfig

${KERNEL_DIR}/scripts/config --file ${OUT_DIR}/.config \
    -e LTO_CLANG \
    -d LTO_NONE \
    -e LTO_CLANG_THIN \
    -d LTO_CLANG_FULL \
    -e THINLTO \
    -d PM_DEBUG \
    -d PM_ADVANCED_DEBUG \
    -d PM_SLEEP_DEBUG

make ${args} olddefconfig

make ${args} Image.lz4

if [ ! -f ${OUT_DIR}/arch/arm64/boot/Image ]; then
    echo "❌ 错误：内核镜像未生成！编译失败。"
    echo "检查 ${OUT_DIR}/arch/arm64/boot/ 目录："
    ls -l ${OUT_DIR}/arch/arm64/boot/ || true
    exit 1
fi

cp -v ${OUT_DIR}/arch/arm64/boot/Image ${HOME}/android_kernel/AnyKernel3
cd ${HOME}/android_kernel/AnyKernel3
ZIP_NAME="AnyKernel3${KSU_BRANCH}${KSU_VERSION}${SUSFS_V}${BBR_V}${NET_V}${MFY_V}${DDP_V}${SSG_V}${BBG_V}-$(date +%Y-%m-%d).zip"
zip -r9v ${OUT_DIR}/${ZIP_NAME} *

echo "====================================="
echo "编译完成！输出文件："
ls ${OUT_DIR}/${ZIP_NAME}
echo "====================================="
