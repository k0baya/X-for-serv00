#!/bin/bash
# 填写变量值时请用半角单引号''进行包裹
export SERV00PASSWORD=''
export UUID=''
export WSPATH=''

USERNAME=$(whoami)
WORKDIR="/home/${USERNAME}/direct-xray"
mkdir -p ${WORKDIR}
cd ${WORKDIR} && \
[ ! -e ${WORKDIR}/entrypoint.sh ] && wget https://raw.githubusercontent.com/k0baya/x-for-serv00/direct/entrypoint.sh -O ${WORKDIR}/entrypoint.sh && chmod +x ${WORKDIR}/entrypoint.sh && \
[ ! -e ${WORKDIR}/app.js ] && wget https://raw.githubusercontent.com/k0baya/x-for-serv00/direct/app.js -O ${WORKDIR}/app.js
sleep 5 
[ ! -e ${WORKDIR}/app.js ] || [ ! -e ${WORKDIR}/entrypoint.sh ] && echo "网络错误！请稍后再试！" && exit 1
nohup node ${WORKDIR}/app.js >/dev/null 2>&1 &
echo 'X-for-Serv00 (Direct Version) is trying to start up, please waiting...'
sleep 7 && cat ${WORKDIR}/list