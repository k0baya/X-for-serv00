## X-for-Serv00

直连版本，不使用 Cloudflare CDN，并且去掉了网页。采用 Vless-xtls-vision-reality、Vmess-tls-ws、Trojan-tls 三协议，每个协议 3 个接入点，共 9 个节点，需要单一账号部署，账号内不得部署其他应用。已通过 Warp 解锁 ChatGPT、Netflix，并添加 IPv6。

### 部署
#### 准备工作
首先在 Panel 中放行三个 TCP 端口，并在 Additional services 选项卡中找到 Run your own applications 项目，将其设置为 Enabled 。

然后是最重要的部分，生成一个 Let's Encrypt 证书：

在 Panel 中点击左侧菜单栏中的 SSL ，然后点击上方菜单栏中的 WWW websites ，点击第一个 IP Address 最右侧的 Manage 按钮，再点击上方菜单栏中的 Add certificate 按钮，Type 选择 Generate Let's Encrypt certificate， Domain任选一个即可，最后点击下方的 Add 按钮进行生成。**请至少保证自己的 Serv00 账号下有一个 Let's Encrypt 的证书，否则无法使用本仓库！**

接着进入 File manager，新建 `~/direct-xray` 路径用于部署 X-for-Serv00，并将本仓库的文件都上传到 `~/direct-xray` 内。
>也可以在 Terminal 中直接使用命令将本仓库文件下载到相应位置：
>```bash
>git clone -b direct https://github.com/k0baya/x-for-serv00 ~/direct-xray
>```

右键点击 `start.sh` 文件，选择 View/Edit > Source Editor ，进行编辑，在 1 - 18 行修改环境变量：
|变量名|是否必须|默认值|备注|
|-|-|-|-|
|SERV00PASSWORD|是||你的 Serv00 账号的密码，用于获取 SSL 证书|
|UUID|否|de04add9-5c68-8bab-950c-08cd5320df18|可在 [Online UUID Generator](https://www.uuidgenerator.net/) 生成|
|WSPATH|否|serv00|勿以 / 开头，协议路径为 /WSPATH-协议，如 /serv00-vmess|

#### 启动并获取配置
SSH 登录 Serv00 ，直接执行启动脚本即可启动。

```
chmod +x ~/direct-xray/start.sh && bash ~/direct-xray/start.sh
```
等待程序完成启动，会在 Terminal 中直接打印出 Vless-xtls-vision-reality、Vmess-tls-ws、Trojan-tls 的配置链接。

### 自动启动

听说 Serv00 的主机会不定时重启，所以需要添加自启任务。

在 Panel 中找到 Cron jobs 选项卡，使用 Add cron job 功能添加任务，Specify time 选择 After reboot，即为重启后运行。Form type 选择 Advanced，Command 写 `start.sh` 文件的绝对路径，比如：

```
/home/username/direct-xray/start.sh >/dev/null 2>&1
```
> 务必按照你的实际路径进行填写。
