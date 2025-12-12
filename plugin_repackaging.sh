#!/bin/bash
# author: Junjie.M

# GITHUB 地址
DEFAULT_GITHUB_API_URL=https://github.com

# DIFY 插件市场地址
DEFAULT_MARKETPLACE_API_URL=https://marketplace.dify.ai

# PIP 镜像地址
DEFAULT_PIP_MIRROR_URL=https://mirrors.aliyun.com/pypi/simple

GITHUB_API_URL="${GITHUB_API_URL:-$DEFAULT_GITHUB_API_URL}"
MARKETPLACE_API_URL="${MARKETPLACE_API_URL:-$DEFAULT_MARKETPLACE_API_URL}"
PIP_MIRROR_URL="${PIP_MIRROR_URL:-$DEFAULT_PIP_MIRROR_URL}"

# 获取当前目录
# dirname $0：获取脚本所在目录的路径（$0 是脚本文件路径）
# cd $CURR_DIR：切换到脚本所在目录
# pwd：获取当前工作目录的绝对路径
# 为什么要这样做：确保 CURR_DIR 是绝对路径，而不是相对路径
CURR_DIR=`dirname $0`
cd $CURR_DIR
CURR_DIR=`pwd`
# whoami：获取当前用户名（虽然定义了但脚本中未使用）
USER=`whoami`
# uname -m：获取机器架构，如 x86_64、arm64、aarch64
ARCH_NAME=`uname -m`
# uname：获取操作系统类型，如 Linux、Darwin（macOS）
OS_TYPE=$(uname)
# 将操作系统名转为小写（Darwin → darwin）
OS_TYPE=$(echo "$OS_TYPE" | tr '[:upper:]' '[:lower:]')
# 选择对应平台的 CLI 工具
CMD_NAME="dify-plugin-${OS_TYPE}-amd64"
if [[ "arm64" == "$ARCH_NAME" || "aarch64" == "$ARCH_NAME" ]]; then
	CMD_NAME="dify-plugin-${OS_TYPE}-arm64"
fi

# 用于跨平台打包的参数，初始为空。命令行参数 -p
PIP_PLATFORM=""
# 输出文件后缀，默认为 "offline"。命令行参数 -s
PACKAGE_SUFFIX="offline"
# 从 Dify Marketplace 下载插件
market(){
	if [[ -z "$2" || -z "$3" || -z "$4" ]]; then
		echo ""
		echo "Usage: "$0" market [plugin author] [plugin name] [plugin version]"
		echo "Example:"
		echo "	"$0" market junjiem mcp_sse 0.0.1"
		echo "	"$0" market langgenius agent 0.0.9"
		echo ""
		exit 1
	fi
	echo "From the Dify Marketplace downloading ..."
	PLUGIN_AUTHOR=$2
	PLUGIN_NAME=$3
	PLUGIN_VERSION=$4
	PLUGIN_PACKAGE_PATH=${CURR_DIR}/${PLUGIN_AUTHOR}-${PLUGIN_NAME}_${PLUGIN_VERSION}.difypkg
	PLUGIN_DOWNLOAD_URL=${MARKETPLACE_API_URL}/api/v1/plugins/${PLUGIN_AUTHOR}/${PLUGIN_NAME}/${PLUGIN_VERSION}/download
	echo "Downloading ${PLUGIN_DOWNLOAD_URL} ..."
	curl -L -o ${PLUGIN_PACKAGE_PATH} ${PLUGIN_DOWNLOAD_URL}
	if [[ $? -ne 0 ]]; then
		echo "Download failed, please check the plugin author, name and version."
		exit 1
	fi
	echo "Download success."
	repackage ${PLUGIN_PACKAGE_PATH}
}

# 从 GitHub Release 下载插件
github(){
	if [[ -z "$2" || -z "$3" || -z "$4" ]]; then
		echo ""
		echo "Usage: "$0" github [Github repo] [Release title] [Assets name (include .difypkg suffix)]"
		echo "Example:"
		echo "	"$0" github junjiem/dify-plugin-tools-dbquery v0.0.2 db_query.difypkg"
		echo "	"$0" github https://github.com/junjiem/dify-plugin-agent-mcp_sse 0.0.1 agent-mcp_see.difypkg"
		echo ""
		exit 1
	fi
	echo "From the Github downloading ..."
	GITHUB_REPO=$2
	if [[ "${GITHUB_REPO}" != "${GITHUB_API_URL}"* ]]; then
		GITHUB_REPO="${GITHUB_API_URL}/${GITHUB_REPO}"
	fi
	RELEASE_TITLE=$3
	ASSETS_NAME=$4
	PLUGIN_NAME="${ASSETS_NAME%.difypkg}"
	PLUGIN_PACKAGE_PATH=${CURR_DIR}/${PLUGIN_NAME}-${RELEASE_TITLE}.difypkg
	PLUGIN_DOWNLOAD_URL=${GITHUB_REPO}/releases/download/${RELEASE_TITLE}/${ASSETS_NAME}
	echo "Downloading ${PLUGIN_DOWNLOAD_URL} ..."
	curl -L -o ${PLUGIN_PACKAGE_PATH} ${PLUGIN_DOWNLOAD_URL}
	if [[ $? -ne 0 ]]; then
		echo "Download failed, please check the github repo, release title and assets name."
		exit 1
	fi
	echo "Download success."
	repackage ${PLUGIN_PACKAGE_PATH}
}

# 处理本地已有的插件包
_local(){
	echo $2
	if [[ -z "$2" ]]; then
		echo ""
		echo "Usage: "$0" local [difypkg path]"
		echo "Example:"
		echo "	"$0" local ./db_query.difypkg"
		echo "	"$0" local /root/dify-plugin/db_query.difypkg"
		echo ""
		exit 1
	fi
	# $2 接收插件路径，并通过realpath将插件路径转为绝对路径
	PLUGIN_PACKAGE_PATH=`realpath $2`
	repackage ${PLUGIN_PACKAGE_PATH}
}

repackage(){
  # local 用于声明局部变量，仅在函数内有效
	local PACKAGE_PATH=$1
	# 提取路径的文件名部分
	PACKAGE_NAME_WITH_EXTENSION=`basename ${PACKAGE_PATH}`
	# 处理插件名，删除最后一个 . 及其后面的内容
	PACKAGE_NAME="${PACKAGE_NAME_WITH_EXTENSION%.*}"
	# 如果文件目录已存在，则尝试删除
	rm -rf PACKAGE_NAME
	echo "Unziping ..."
	# 安装 unzip
	install_unzip
	# 解压插件包，到 当前目录/插件名 的目录下
	unzip -o ${PACKAGE_PATH} -d ${CURR_DIR}/${PACKAGE_NAME}
	if [[ $? -ne 0 ]]; then
		echo "Unzip failed."
		exit 1
	fi
	echo "Unzip success."
	echo "Repackaging ..."
	# 进入解压后的插件目录
	cd ${CURR_DIR}/${PACKAGE_NAME}
	# 下载 Python 依赖
	# pip download 参数详解：
  #    - ${PIP_PLATFORM}：可选的跨平台参数（如 --platform manylinux_2_17_x86_64 --only-binary=:all:）
  #    - --only-binary=:all:：只下载预编译的二进制包（wheels），不下载源码包
  #    - -r requirements.txt：从 requirements.txt 读取依赖列表
  #    - -d ./wheels：下载到 wheels 目录
  #    - --index-url：指定 PyPI 镜像地址
  #    - --trusted-host mirrors.aliyun.com：信任阿里云镜像主机（避免 SSL 警告）
	pip download ${PIP_PLATFORM}  -r requirements.txt -d ./wheels --index-url ${PIP_MIRROR_URL} --trusted-host mirrors.aliyun.com
	if [[ $? -ne 0 ]]; then
		echo "Pip download failed."
		exit 1
	fi
	# 修改 requirements.txt（平台差异处理）
	# 在文件第一行之前插入 --no-index --find-links=./wheels/
	# --no-index：不使用 PyPI 索引
  # --find-links=./wheels/：从本地 wheels 目录查找包
  # 这样 pip install 时会使用离线的 wheels
	if [[ "linux" == "$OS_TYPE" ]]; then
		sed -i '1i\--no-index --find-links=./wheels/' requirements.txt
	elif [[ "darwin" == "$OS_TYPE" ]]; then
		sed -i ".bak" '1i\
--no-index --find-links=./wheels/
	  ' requirements.txt
		rm -f requirements.txt.bak
	fi

  # 修改忽略文件，确保 wheels 目录不被忽略，会被打包进去
	IGNORE_PATH=.difyignore
	# 优先使用 .difyignore，不存在则使用 .gitignore
	if [ ! -f "$IGNORE_PATH" ]; then
		IGNORE_PATH=.gitignore
	fi
	#
	if [ -f "$IGNORE_PATH" ]; then
		if [[ "linux" == "$OS_TYPE" ]]; then
		  # 删除以 wheels/ 开头的行
			sed -i '/^wheels\//d' "${IGNORE_PATH}"
		elif [[ "darwin" == "$OS_TYPE" ]]; then
			sed -i ".bak" '/^wheels\//d' "${IGNORE_PATH}"
			rm -f "${IGNORE_PATH}.bak"
		fi
	fi
	# 使用 dify-plugin CLI 重新打包
  # cd ${CURR_DIR}：返回脚本目录
  # chmod 755：给 dify-plugin 工具添加执行权限
  # plugin package 命令参数：
  #   - 源目录：${CURR_DIR}/${PACKAGE_NAME}
  #   - -o：输出文件路径
  #   - --max-size 5120：最大包大小 5120MB（5GB）
  # 输出文件名格式：包名-offline.difypkg（suffix 默认是 "offline"）
	cd ${CURR_DIR}
	chmod 755 ${CURR_DIR}/${CMD_NAME}
	${CURR_DIR}/${CMD_NAME} plugin package ${CURR_DIR}/${PACKAGE_NAME} -o ${CURR_DIR}/${PACKAGE_NAME}-${PACKAGE_SUFFIX}.difypkg --max-size 5120
	if [ $? -ne 0 ]; then
    echo "Repackage failed."
    exit 1
  fi
	echo "Repackage success."
}

# 安装 unzip 工具
# command -v unzip：检查 unzip 命令是否存在
# ! command：取反，命令不存在时为真
# &> /dev/null：重定向标准输出和标准错误到 /dev/null（丢弃输出）
# yum -y install unzip：自动确认安装 unzip
# 局限性：只适用于使用 yum 的系统（RHEL、CentOS 等）
install_unzip(){
	if ! command -v unzip &> /dev/null; then
		echo "Installing unzip ..."
		yum -y install unzip
		if [ $? -ne 0 ]; then
			echo "Install unzip failed."
			exit 1
		fi
	fi
}

print_usage() {
	echo "usage: $0 [-p platform] [-s package_suffix] {market|github|local}"
	echo "-p platform: python packages' platform. Using for crossing repacking.
        For example: -p manylinux2014_x86_64 or -p manylinux2014_aarch64"
	echo "-s package_suffix: The suffix name of the output offline package.
        For example: -s linux-amd64 or -s linux-arm64"
	exit 1
}

# 解析命令行选项
# getopts
# 作用：Shell内置命令，用于解析命令行选项
# 语法：getopts optstring name
# "p:s:"：选项字符串（optstring）
#   - p:：定义选项 -p，冒号表示需要参数
#   - s:：定义选项 -s，冒号也表示需要参数
#   - 如果是 "ps"（无冒号），表示选项不需要参数
# opt：变量名，存储当前解析到的选项字母
# OPTARG：当前选项的参数值
# -p 示例：-p manylinux_2_17_x86_64 会设置 PIP_PLATFORM="--platform manylinux_2_17_x86_64 --only-binary=:all:"
# -s 示例：-s linux-amd64 会设置 PACKAGE_SUFFIX="linux-amd64"
while getopts "p:s:" opt; do
	case "$opt" in
		p) PIP_PLATFORM="--platform ${OPTARG} --only-binary=:all:" ;;
		s) PACKAGE_SUFFIX="${OPTARG}" ;;
		*) print_usage; exit 1 ;;
	esac
done

# 移除已处理的选项
#  - $OPTIND：getopts 处理后的下一个参数位置
#  - shift N：将位置参数左移 N 个
#  - 效果：移除所有选项参数，剩下的 $1 就是子命令（market/github/local）
shift $((OPTIND - 1))

echo "$1"
# $@：所有位置参数（包括 $1）
# ;;：case 分支结束标记
# *)：默认分支，匹配所有未处理的情况
# 最后 exit 0 表示成功退出
case "$1" in
	'market') market $@ ;;
	'github') github $@ ;;
	'local') _local $@ ;;
	*)

print_usage
exit 1
esac
exit 0
