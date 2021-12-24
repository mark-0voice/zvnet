# zvnet  

>   zero voice net framework; just like openresty cosocket.



# 克隆 zvnet 源代码

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

