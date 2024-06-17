>鸣谢 fscarmen2 的开源仓库 [fscarmen2/Argo-Xray-JS-PaaS](https://github.com/fscarmen2/Argo-Xray-JS-PaaS) ，本仓库是基于此仓库的基础进行了 FreeBSD 相关命令的替换，并根据 Serv00 的实际环境进行了部分功能的删减与增加。

## X-for-Serv00

项目特点与 Argo-Xray-JS-PaaS 基本一致，但是由于 Serv00 端口数量限制，本仓库仅实现了 vmess 协议，并删除了 webssh 以及 webftp 以及探针的功能。

而且本仓库流量默认全局 Warp ，使得代理能够正常访问 IPv6 资源。

且本仓库在源仓库的基础上添加了订阅功能，在`/list`路径列表下可以看到订阅地址，如果不固定 ARGO 隧道，也可以通过订阅地址获取最新配置，而不需要打开网页查看。

### 部署

首先在 Panel 中放行三个个端口，接着按照下表 Add a New Website ：

| Key          | Value                                                                          |
| ------------ | ------------------------------------------------------------------------------ |
| Domain       | `xxx.USERNAME.serv00.net`（也可以把原有的 USERNAME.serv00.net 删掉后重新添加） |
| Website Type | proxy                                                                          |
| Proxy Target | localhost                                                                      |
| Proxy URL    | 留空                                                                           |
| Proxy port   | 你准备用来部署本仓库的 WEB 的端口（即 `start.sh` 变量中的`WEBPORT`）                                                    |
| Use HTPPS    | False                                                                          |
| DNS support  | True                                                                           |

添加完新站点后，继续点击上方的 Manage SSL certificates ，接着在出口 IP 的右侧点击 Manage ，再点击 Add certificate ：

| Type                                 | Domain                                                                           |
| ------------------------------------ | -------------------------------------------------------------------------------- |
| Generate Let's Encrypted certificate | 与刚刚添加的站点域名保持一致（如果是原有的`USERNAME.serv00.net` ，可以省略此步） |

接着进入 File manager，并进入刚刚你新建的域名目录下，将本仓库的文件都上传到此目录下。

右键点击 `start.sh` 文件，选择 View/Edit > Source Editor ，进行编辑，在 1 - 18 行修改环境变量：
|变量名|是否必须|默认值|备注|
|-|-|-|-|
|WEBPORT|是||网页端口，查看代理配置、获取订阅链接等等功能需要|
|LISTENPORT|是||Xray 监听端口|
|VMPORT|是||Vmess 协议监听端口|
|UUID|是|de04add9-5c68-8bab-950c-08cd5320df18||
|WSPATH|是|serv00|勿以 / 开头，协议路径为 /WSPATH-协议，如 /serv00-vmess|
|ARGO_AUTH|否||Argo 的 Token 值，ey 开头的一串，获取方法可以参考[群晖套件：Cloudflare Tunnel 内网穿透中文教程 支持DSM6、7](https://imnks.com/5984.html)|
|ARGO_DOMAIN|否||Argo 的域名，须与 ARGO_DOMAIN 必需一起填了才能生效|
|WEB_USERNAME|否|admin|网页的用户名|
|WEB_PASSWORD|否|password|网页的密码|

接着在 Cloudflare Argo Tunnel 的面板中，给这条隧道添加一个域名，域名为刚刚填写的 `ARGO_DOMAIN` ，协议为 `HTTP` ，地址为`localhost:`加上刚刚填写的 `VMPORT` （如 `localhost:54321` ）。

最后 SSH 登录 Serv00 ，进入 `start.sh` 所在的路径，直接执行即可启动。

```
chmod +x start.sh && bash start.sh
```
最后等待一分钟左右，等程序完全启动，再打开之前添加的 `Websites` ，并进入`/list`路径（如`https://xxx.USERNAME.serv00.net/list`）获取代理配置。

### 自动启动

听说 Serv00 的主机会不定时重启，所以需要添加自启任务。

在 Panel 中找到 Cron jobs 选项卡，使用 Add cron job 功能添加任务，Specify time 选择 After reboot，即为重启后运行。Form type 选择 Advanced，Command 写 `start.sh` 文件的绝对路径，比如：

```
/home/username/domains/argo-x/start.sh
```
> 务必按照你的实际路径进行填写。
