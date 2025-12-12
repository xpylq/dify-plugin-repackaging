## 功能
本插件核心目的是制作一个可在完全离线条件下，在 dify 上安装的插件包

## 使用指南
1. 找一台 linux 服务器
2. 安装 dify-plugin-daemon 一致的 python 环境，这里以 conda 为例
    * 创建环境: `conda create -n repackage python=3.12.3`
    * 激活环境: `conda activate repackage`
3. 执行脚本: `bash plugin_repackaging.sh -p manylinux_2_17_x86_64 local <下载的离线插件绝对路径>`
4. 修改 dify 对应的配置文件，并重启 dify-api、nginx、dify-plugin-daemon 服务
   * `FORCE_VERIFYING_SIGNATURE=false`，禁用签名确认，允许安装非 dify 官方市场的插件
   * `PLUGIN_MAX_PACKAGE_SIZE=524288000`，增加 dify 可安装插件的大小
   * `NGINX_CLIENT_MAX_BODY_SIZE=500M`，增加 nginx 可上传文件的大小


## 原理
1. dify的插件以`.difypkg`结尾，本质就是zip压缩包
2. 脚本通过解压zip包，手动通过`pip`下载对应的依赖到指定的`./wheels`目录，然后再重新使用官方的二进制工具重新打包

## 修改内容
1. 增加必要注释
2. 优化了多次对同一个插件处理的逻辑，避免出现异常
3. 优化了说明文档


## 参考
1. [项目源码](https://github.com/junjiem/dify-plugin-repackaging)
2. [dify-plugin-daemon](https://github.com/langgenius/dify-plugin-daemon)

## 其他问题
### 由于 GCC 版本过低，导致安装 NumPy 失败
1. 安装软件仓库: `sudo yum install -y centos-release-scl`
2. 配置 SCL 源（可选）
   * 修改 `/etc/yum.repos.d/CentOS-SCLo-scl.repo`
   * 注释失效的镜像: `#mirrorlist=http://mirrorlist.centos.org?arch=$basearch&release=7&repo=sclo-sclo`
   * 修改基础地址为阿里云: `baseurl=https://mirrors.aliyun.com/centos/7/sclo/x86_64/rh/`
   * 清理并重建 Yum 缓存: `sudo yum clean all && yum makecache`
3. 安装 GCC 9.3 及相关工具链: `sudo yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils`
4. 在当前会话中激活新版本的GCC: `scl enable devtoolset-9 bash`
