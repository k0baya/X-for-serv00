## X-for-Serv00

直连版本，不使用 Cloudflare CDN。采用 Vless-xtls-vision-reality、Vmess-tls-ws、Trojan-tls 三协议，每个协议 3 个接入点，共 9 个节点，需要单一账号部署，账号内不得部署其他应用。已通过 Warp 解锁 ChatGPT、Netflix，并添加 IPv6。

### 部署
#### 准备工作

首先你需要 1 个 Serv00 的账号。

>如果你之前放行过端口，请确保你的端口不是 UDP 类型，如果放行过 UDP 端口，请将其删除。

然后是最重要的部分，生成一个 Let's Encrypt 证书：

在 Panel 中点击左侧菜单栏中的 SSL ，然后点击上方菜单栏中的 WWW websites ，点击第一个 IP Address 最右侧的 Manage 按钮，再点击上方菜单栏中的 Add certificate 按钮，Type 选择 Generate Let's Encrypt certificate， Domain任选一个即可，最后点击下方的 Add 按钮进行生成。**请至少保证自己的 Serv00 账号下有一个 Let's Encrypt 的证书，否则无法使用本仓库！**

>友情提示，自己的域名添加 A 类型 DNS 记录指向 Serv00 的服务器后，也可以使用 Serv00 的面板内置的功能添加 Let's Encrypt 的证书，且对本仓库的运行同样有效。同时，自己的域名不受 Serv00 自带域名申请 SSL 证书时的每周数量限制。

#### 部署 X-for-Serv00

SSH 登录 Serv00，输入以下命令以激活运行许可：
```shell
devil binexec on
```
接着断开 SSH 并重新连接，输入以下命令：
```shell
bash <(curl -Ls https://raw.githubusercontent.com/k0baya/x-for-serv00/direct/entrypoint.sh)
```
并按照提示输入相关信息。

#### 启动并获取配置

按照脚本提示进入 `/status` 的网页，并尝试刷新页面，直到进程列表中出现了包含 `web.js` 字样的进程，就代表 X-for-Serv00 已经启动成功。此时你就可以通过访问 `/list` 路径查看到 X-for-Serv00 所提供的配置链接了。

### 自动启动

此次版本更新之后，X-for-Serv00 已经可以摆脱 Serv00 的 Crontab 启动，你可以通过访问网页对项目进行唤醒，如果你需要保活，可以使用以下公共服务对网页进行监控：

1 [cron-job.org](https://console.cron-job.org)

2 [UptimeRobot](https://uptimerobot.com/) 

同时，你也可以选择自建 [Uptime-Kuma](https://github.com/louislam/uptime-kuma) 等服务进行监控。

>建议监控 `/info` 路径，因为该路径无需身份验证。
>
>不要监控根路径，因为根路径为静态页面，只是该项目的伪装，无法起到保活效果。

### 常见问题

1. 为什么放行端口失败？

如果脚本自动放行端口失败，请手动去面板中添加三个类型为 TCP 的端口，再重新执行安装脚本。

2. 为什么连不上？

如果 `/status` 页面中 `web.js` 进程正常运行，那么说明本项目运行正常，连接不上说明 Serv00 被 GFW 拦截了。

补充中...
