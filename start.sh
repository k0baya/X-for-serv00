#!/bin/bash

# 端口参数 （必填）
export WEBPORT=
export LISTENPORT=
export VMPORT=

# web.js 参数 （必填）
export UUID=de04add9-5c68-8bab-950c-08cd5320df18
export WSPATH=serv00

# ARGO 隧道参数（如需固定 ARGO 隧道，请把 ey 开头的 ARGO 隧道的 token 填入 ARGO_AUTH ，仅支持这一种方式固定，隧道域名代理的协议为 HTTP ，端口为 VMPORT 同端口。如果不固定 ARGO 隧道，请删掉ARGO_DOMAIN那行，保留ARGO_AUTH这行。）
export ARGO_AUTH=''
export ARGO_DOMAIN=

# 网页的用户名和密码（可不填，默认为 admin 和 password ，如果不填请删掉这两行）
export WEB_USERNAME=
export WEB_PASSWORD=

# 启动程序
npm install && \
nohup node server.js 2>/dev/null 2>&1 &