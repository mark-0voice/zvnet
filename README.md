# zvnet  

>   zero voice net framework




#### 环境准备

```shell
# 克隆 openresty 版本的 luajit
git clone https://github.com/openresty/luajit2.git

# 进入目录
cd luajit2

# 安装编译 luajit
make && sudo make install

# 刷新动态链接库
sudo ldconfig

# 克隆 zvnet 源代码

```



#### 安装编译

1.  centos、ubuntu：

    ```shell
    make linux
    ```

2.  macos：

    ```shell
    make macosx
    ```



#### 使用说明

```shell
# 开启服务端
./zvnet example/echo-srv.lua
# 开启客户端
./zvnet example/echo-cli.lua
```

