#!/usr/bin/bash

USERNAME=$(whoami)
USERNAME_DOMAIN=$(whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
WORKDIR="/home/${USERNAME}/domains/${USERNAME_DOMAIN}.serv00.net/public_nodejs"
WSPATH=${WSPATH:-'serv00'}
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WEB_USERNAME=${WEB_USERNAME:-'admin'}
WEB_PASSWORD=${WEB_PASSWORD:-'password'}

set_language() {
    devil lang set english
}

set_domain_dir() {
    local DOMAIN="${USERNAME_DOMAIN}.serv00.net"
    if devil www list | grep nodejs | grep "/domains/${DOMAIN}"; then
        if [ ! -d ${WORKDIR}/public ]; then
            git clone https://github.com/k0baya/mikutap ${WORKDIR}/public
        fi
        return 0
    else
        echo "正在检测 NodeJS 环境，请稍候..."
        nohup devil www del ${DOMAIN} >/dev/null 2>&1
        devil www add ${DOMAIN} nodejs /usr/local/bin/node22
        rm -rf ${WORKDIR}/public
        git clone https://github.com/k0baya/mikutap ${WORKDIR}/public
    fi
}

reserve_port() {
    local port_list
    local port_count
    local current_port
    local needed_ports
    local max_attempts
    local attempts

    local add_port
    add_port() {
        local port=$1
        local result=$(devil port add tcp "$port")
        echo "尝试添加预留端口 $port: $result" 
    }

    local delete_udp_port
    delete_udp_port() {
        local port=$1
        local result=$(devil port del udp "$port")
        echo "删除 UDP 端口 $port: $result"
    }

    update_port_list() {
        port_list=$(devil port list)
        port_count=$(echo "$port_list" | grep -c 'tcp')
    }

    # 循环删除 UDP 端口
    port_list=$(devil port list)
    while echo "$port_list" | grep -q 'udp'; do
        UDP_PORT=$(echo "$port_list" | grep 'udp' | awk 'NR==1{print $1}')
        delete_udp_port $UDP_PORT
        update_port_list
    done

    update_port_list

    # 随机选择起始端口
    start_port=$(( RANDOM % 63077 + 1024 ))  # 1024-64000之间的随机数

    if [ $start_port -le 32512 ]; then
        current_port=$start_port
        increment=1
    else
        current_port=$start_port
        increment=-1
    fi

    max_attempts=100 
    attempts=0

    if [ "$port_count" -ge 3 ]; then
        PORT1=$(echo "$port_list" | grep 'tcp' | awk 'NR==1{print $1}')
        PORT2=$(echo "$port_list" | grep 'tcp' | awk 'NR==2{print $1}')
        PORT3=$(echo "$port_list" | grep 'tcp' | awk 'NR==3{print $1}')
        echo "预留端口为 $PORT1 $PORT2 $PORT3"
        return 0
    else
        needed_ports=$((3 - port_count))

        while [ $needed_ports -gt 0 ]; do
            if add_port $current_port; then
                update_port_list
                needed_ports=$((3 - port_count))

                if [ $needed_ports -le 0 ]; then
                    break
                fi
            fi
            current_port=$((current_port + increment))
            attempts=$((attempts + 1))

            if [ $attempts -ge $max_attempts ]; then
                echo "超过最大尝试次数，无法添加足够的预留端口"
                exit 1
            fi
        done
    fi

    update_port_list
    PORT1=$(echo "$port_list" | grep 'tcp' | awk 'NR==1{print $1}')
    PORT2=$(echo "$port_list" | grep 'tcp' | awk 'NR==2{print $1}')
    PORT3=$(echo "$port_list" | grep 'tcp' | awk 'NR==3{print $1}')
    echo "预留端口为 $PORT1 $PORT2 $PORT3"
}



generate_dotenv() {

    generate_uuid() {
    local uuid
    uuid=$(uuidgen -r)
    while [[ ${uuid:0:1} =~ [0-9] ]]; do
        uuid=$(uuidgen -r)
    done
    echo "$uuid"
    }

    printf "请输入 ARGO_AUTH（必填）："
    read -r ARGO_AUTH
    printf "请输入 ARGO_DOMAIN_VL（必填）："
    read -r ARGO_DOMAIN_VL
    echo "请在Cloudflare中为隧道添加域名 ${ARGO_DOMAIN_VL} 指向 HTTP://localhost:${PORT1},添加完成请按回车继续"
    read
    printf "请输入 ARGO_DOMAIN_VM（必填）："
    read -r ARGO_DOMAIN_VM
    echo "请在Cloudflare中为隧道添加域名 ${ARGO_DOMAIN_VM} 指向 HTTP://localhost:${PORT2},添加完成请按回车继续"
    read
    printf "请输入 ARGO_DOMAIN_TR（必填）："
    read -r ARGO_DOMAIN_TR
    echo "请在Cloudflare中为隧道添加域名 ${ARGO_DOMAIN_TR} 指向 HTTP://localhost:${PORT3},添加完成请按回车继续"
    read
    printf "请输入 UUID（默认值：de04add9-5c68-8bab-950c-08cd5320df18）："
    read -r UUID
    printf "请输入 WSPATH（默认值：serv00）："
    read -r WSPATH
    printf "请输入 WEB_USERNAME（默认值：admin）："
    read -r WEB_USERNAME
    printf "请输入 WEB_PASSWORD（默认值：password）："
    read -r WEB_PASSWORD

    if [ -z "${ARGO_AUTH}" ] || [ -z "${ARGO_DOMAIN_VL}" ] || [ -z "${ARGO_DOMAIN_VM}" ] || [ -z "${ARGO_DOMAIN_TR}" ]; then
    echo "Error! 所有选项都不能为空！"
    rm -rf ${WORKDIR}/*
    rm -rf ${WORKDIR}/.*
    exit 1
    fi

    if [ -z "${UUID}" ]; then
        echo "正在生成 UUID..."
        UUID=$(generate_uuid)
    fi
    if [ -z "${WSPATH}" ]; then
        WSPATH='serv00'
    fi
    if [ -z "${WEB_USERNAME}" ]; then
        WEB_USERNAME='admin'
    fi
    if [ -z "${WEB_PASSWORD}" ]; then
        WEB_PASSWORD='password'
    fi

    cat > ${WORKDIR}/.env << EOF
ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN_VL=${ARGO_DOMAIN_VL}
ARGO_DOMAIN_VM=${ARGO_DOMAIN_VM}
ARGO_DOMAIN_TR=${ARGO_DOMAIN_TR}
UUID=${UUID}
WSPATH=${WSPATH}
WEB_USERNAME=${WEB_USERNAME}
WEB_PASSWORD=${WEB_PASSWORD}
EOF
}

get_app() {
    echo "正在下载 app.js 请稍候..."
    wget -t 10 -qO ${WORKDIR}/app.js https://raw.githubusercontent.com/k0baya/X-for-serv00/main/app.js
    if [ $? -ne 0 ]; then
        echo "app.js 下载失败！请检查网络情况！"
        exit 1
    fi
    echo "正在下载 package.json 请稍候..."
    wget -t 10 -qO ${WORKDIR}/package.json https://raw.githubusercontent.com/k0baya/X-for-serv00/main/package.json
    if [ $? -ne 0 ]; then
        echo "package.json 下载失败！请检查网络情况！"
        exit 1
    fi

    echo "正在安装依赖..."
    nohup npm22 install > /dev/null 2>&1
}

get_core() {
    local TMP_DIRECTORY=$(mktemp -d)
    local ZIP_FILE="${TMP_DIRECTORY}/Xray-freebsd-64.zip"
    echo "正在下载 Web.js 请稍候..."
    wget -t 10 -qO "$ZIP_FILE" https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip
    if [ $? -ne 0 ]; then
        echo "Web.js 安装失败！请检查网络情况！"
        exit 1
    else
        unzip -qo "$ZIP_FILE" -d "$TMP_DIRECTORY"
        install -m 755 "${TMP_DIRECTORY}/xray" "${WORKDIR}/web.js"
        rm -rf "$TMP_DIRECTORY"
    fi
}


generate_config() {
    cat > ${WORKDIR}/config.json << EOF
{
    "log": {
        "loglevel": "error"
    },
    "inbounds":[
        {
            "port":${PORT1},
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-vless"
                }
            }
        },
        {
            "port":${PORT2},
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-vmess"
                }
            }
        },
        {
            "port":${PORT3},
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-trojan"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4"
            },
            "streamSettings": {
                "sockopt": {
                    "tcpFastOpen": true
                }
            }
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "block"
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": ["::/0"]
            }
        ]
    }
}
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/bash

USERNAME=\$(whoami)
USERNAME_DOMAIN=\$(whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
WORKDIR="/home/\${USERNAME}/domains/\${USERNAME_DOMAIN}.serv00.net/public_nodejs"

cd \${WORKDIR}
source \${WORKDIR}/.env

check_file() {
    wget -t 10 https://cloudflared.bowring.uk/binaries/cloudflared-freebsd-latest.7z

    if [ \$? -ne 0 ]; then
        echo "Cloudflared 客户端安装失败！请检查 hosts 文件是否屏蔽了下载地址！" > list
        exit 1
    else
        7z x cloudflared-freebsd-latest.7z -bb > /dev/null \
        && rm cloudflared-freebsd-latest.7z \
        && mv -f ./temp/* ./cloudflared \
        && rm -rf temp \
        && chmod +x cloudflared
    fi
}


run() {
        if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN_VL}" && -n "\${ARGO_DOMAIN_VM}" && -n "\${ARGO_DOMAIN_TR}" ]]; then
        if [[ "\$ARGO_AUTH" =~ TunnelSecret ]]; then
            echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > \${WORKDIR}/tunnel.json
            cat > \${WORKDIR}/tunnel.yml << EOF
tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")
credentials-file: \${WORKDIR}/tunnel.json
protocol: http2

ingress:
  - hostname: \$ARGO_DOMAIN_VL
    service: http://localhost:\${PORT1}
  - hostname: \$ARGO_DOMAIN_VM
    service: http://localhost:\${PORT2}
  - hostname: \$ARGO_DOMAIN_TR
    service: http://localhost:\${PORT3}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
            nohup ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml run > /dev/null 2>&1 &
        elif [[ "\$ARGO_AUTH" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
            nohup ./cloudflared tunnel --edge-ip-version auto --protocol http2 run --token \${ARGO_AUTH} > /dev/null 2>&1 &
        fi
    else
        echo '请设置环境变量 \$ARGO_AUTH 和 \$ARGO_DOMAIN_TR、\$ARGO_DOMAIN_VL、\$ARGO_DOMAIN_VM' > \${WORKDIR}/list
        exit 1
    fi
    }

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-k0baya-Vmess\", \"add\": \"upos-sz-mirrorcf1ov.bilivideo.com\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN_VM}\", \"path\": \"/${WSPATH}-vmess?ed=2560\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN_VM}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?path=%2F${WSPATH}-vless%3Fed%3D2560&security=tls&encryption=none&host=\${ARGO_DOMAIN_VL}&type=ws&sni=\${ARGO_DOMAIN_VL}#Argo-k0baya-Vless
----------------------------
vmess://\$(echo \$VMESS | base64 | tr -d '\n')
----------------------------
trojan://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?path=%2F${WSPATH}-trojan%3Fed%3D2560&security=tls&host=\${ARGO_DOMAIN_TR}&type=ws&sni=\${ARGO_DOMAIN_TR}#Argo-k0baya-Trojan
*******************************************
小火箭:
----------------------------
vless://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?encryption=none&security=tls&type=ws&host=\${ARGO_DOMAIN_VL}&path=/${WSPATH}-vless?ed=2560&sni=\${ARGO_DOMAIN_VL}#Argo-k0baya-Vless
----------------------------
vmess://$(echo "none:${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443" | base64 | tr -d '\n')?remarks=Argo-k0baya-Vmess&obfsParam=\${ARGO_DOMAIN_VM}&path=/${WSPATH}-vmess?ed=2560&obfs=websocket&tls=1&peer=\${ARGO_DOMAIN_VM}&alterId=0
----------------------------
trojan://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?peer=\${ARGO_DOMAIN_TR}&plugin=obfs-local;obfs=websocket;obfs-host=\${ARGO_DOMAIN_TR};obfs-uri=/${WSPATH}-trojan?ed=2560#Argo-k0baya-Trojan
*******************************************
Clash:
----------------------------
- {name: Argo-k0baya-Vless, type: vless, server: upos-sz-mirrorcf1ov.bilivideo.com, port: 443, uuid: ${UUID}, tls: true, servername: \${ARGO_DOMAIN_VL}, skip-cert-verify: false, network: ws, ws-opts: {path: /${WSPATH}-vless?ed=2560, headers: { Host: \${ARGO_DOMAIN_VL}}}, udp: true}
----------------------------
- {name: Argo-k0baya-Vmess, type: vmess, server: upos-sz-mirrorcf1ov.bilivideo.com, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess?ed=2560, headers: {Host: \${ARGO_DOMAIN_VM}}}, udp: true}
----------------------------
- {name: Argo-k0baya-Trojan, type: trojan, server: upos-sz-mirrorcf1ov.bilivideo.com, port: 443, password: ${UUID}, udp: true, tls: true, sni: \${ARGO_DOMAIN_TR}, skip-cert-verify: false, network: ws, ws-opts: { path: /${WSPATH}-trojan?ed=2560, headers: { Host: \${ARGO_DOMAIN_TR} } } }
*******************************************
EOF

echo \$(echo -n "vless://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?path=%2F${WSPATH}-vless%3Fed%3D2560&security=tls&encryption=none&host=\${ARGO_DOMAIN_VL}&type=ws&sni=\${ARGO_DOMAIN_VL}#Argo-k0baya-Vless

vmess://\$(echo \$VMESS | base64 | tr -d '\n')

trojan://${UUID}@upos-sz-mirrorcf1ov.bilivideo.com:443?path=%2F${WSPATH}-trojan%3Fed%3D2560&security=tls&host=\${ARGO_DOMAIN_TR}&type=ws&sni=\${ARGO_DOMAIN_TR}#Argo-k0baya-Trojan" | base64 ) > sub

}
[ ! -e \${WORKDIR}/cloudflared ] && check_file
run
export_list
ABC
}

set_language
set_domain_dir
reserve_port

cd ${WORKDIR}
[ ! -e ${WORKDIR}/.env ] && generate_dotenv
[ ! -e ${WORKDIR}/app.js ] || [ ! -e ${WORKDIR}/package.json ] && get_app
[ ! -e ${WORKDIR}/web.js ] && get_core
generate_config
generate_argo

[ -e ${WORKDIR}/argo.sh ] && echo "请访问 https://${USERNAME_DOMAIN}.serv00.net/status 获取服务端状态, 当 cloudflared 与 web.js 正常运行后，访问 https://${USERNAME_DOMAIN}.serv00.net/list 获取配置"
