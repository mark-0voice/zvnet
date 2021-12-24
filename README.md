# zvnet  

>   zero voice net framework; just like openresty cosocket.



### 依赖

#### ubuntu

```shell
apt-get install autoconf
```

#### centos

```shell
yum install -y autoconf
```

#### macos

```shell
brew install autoconf
```


### 安装编译

#### centos、ubuntu

```shell
make linux
```

#### macos

```shell
make macosx
```



### 使用说明

```shell
# 开启服务端
./zvnet example/echo-srv.lua
# 另起一个终端：开启客户端
./zvnet example/echo-cli.lua
```

