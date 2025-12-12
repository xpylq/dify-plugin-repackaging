## 功能
本插件核心目的是制作一个可在完全离线条件下，在dify上安装的插件包

## 使用指南
1. 安装plugin_deamon一致的python环境，这里以conda为例
    * 创建环境: `conda create -n repackage python=3.12.3`
    * 激活环境: `conda activate repackage`
2. 执行脚本: `bash plugin_repackaging.sh -p manylinux_2_17_x86_64 local <下载的离线插件绝对路径>`

### 原理
1. dify的插件以`.difypkg`结尾，本质就是zip压缩包
2. 脚本通过解压zip包，手动通过`pip`下载对应的依赖到指定的`./wheels`目录，然后再重新使用官方的二进制工具重新打包

### 修改内容
1. 增加必要注释
2. 优化了多次对同一个插件处理的逻辑，避免出现异常
3. 优化了说明文档