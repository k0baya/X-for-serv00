WSPATH=${WSPATH:-'serv00'} 
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}

USERNAME=$(whoami)
USERNAME_DOMAIN=$(whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
WORKDIR="/home/${USERNAME}/domains/${USERNAME_DOMAIN}.serv00.net/public_nodejs"

set_language() {
    devil lang set english
}

set_domain_dir() {
    local DOMAIN="${USERNAME_DOMAIN}.serv00.net"
    if devil www list | grep nodejs | grep "/domains/${DOMAIN}"; then
        if [ ! -d ${WORKDIR}/public ]; then
            git clone https://github.com/k0baya/Patatap ${WORKDIR}/public
        fi
        return 0
    else
        echo "正在检测 NodeJS 环境，请稍候..."
        nohup devil www del ${DOMAIN} >/dev/null 2>&1
        devil www add ${DOMAIN} nodejs /usr/local/bin/node22
        rm -rf ${WORKDIR}/public
        git clone https://github.com/k0baya/Patatap ${WORKDIR}/public
    fi
}

generate_config(){
#     local XRAYKEY=$(${WORKDIR}/xray x25519 | grep '^Private' | awk '{print $3}')
    cat > ${WORKDIR}/config.json << EOF
{
    "log": {
        "loglevel": "error"
    },
    "inbounds": [
            {
                "listen": "0.0.0.0",
                "port": ${PORT1},
                "protocol": "vless",
                "settings": {
                    "clients": [
                        {
                            "id": "${UUID}", 
                            "flow": "xtls-rprx-vision"
                        }
                    ],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                    "show": false,
                    "privateKey": "QOh5Yp8ODR9uNVxZsItIn5yyXzfzOGqG4bZakKUu4Ss", 
                    "shortIds": ["ff04"],
                    "Dest": "128.204.218.63:443", 
                    "type": "tcp",
                    "serverNames": [
                        "www.serv00.com",
                        "serv00.com"
                    ]
                    }
                }
        },
        {
            "listen": "0.0.0.0",
            "port": ${PORT2},  
            "protocol": "vmess",  
            "settings": {
              "clients": [
                {
                  "id": "${UUID}",  
                  "alterId": 0
                }
              ]
            },
            "streamSettings": {
              "network": "ws",  
              "security": "tls",  
              "tlsSettings": {
                "certificates": [
                  {
                    "certificateFile": "${WORKDIR}/cert.crt",  
                    "keyFile": "${WORKDIR}/private.key"  
                  }
                ]
              },
              "wsSettings": {
                "path": "${WSPATH}-vmess"  
              }
            }
        },
        {
        "port": ${PORT3},  
        "protocol": "trojan",  
        "settings": {
            "clients": [
            {
                "password": "${UUID}"  
            }
            ]
        },
        "streamSettings": {
            "network": "tcp",  
            "security": "tls",  
            "tlsSettings": {
            "certificates": [
                {
                "certificateFile": "${WORKDIR}/cert.crt",  
                "keyFile": "${WORKDIR}/private.key"  
                }
            ]
            }
        }
        }        
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ],
    "routing":{
        "domainStrategy":"AsIs",
        "rules":[
            {
                "type":"field",
                "domain":[
                    "geosite:category-ads-all"
                ],
                "outboundTag":"block"
            }
        ]
    }
}
EOF
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

    printf "请输入你的 Serv00 用户的密码（必填）："
    read -r SERV00PASSWORD
    printf "请输入 UUID（默认值：de04add9-5c68-8bab-950c-08cd5320df18）："
    read -r UUID
    printf "请输入 WSPATH（默认值：serv00）："
    read -r WSPATH
    printf "请输入 WEB_USERNAME（默认值：admin）："
    read -r WEB_USERNAME
    printf "请输入 WEB_PASSWORD（默认值：password）："
    read -r WEB_PASSWORD

    if [ -z "${SERV00PASSWORD}" ]; then
    echo "Error! 密码不能为空！"
    rm -rf ${WORKDIR}/*
    rm -rf ${WORKDIR}/.*
    exit 1
    fi

    if [ -z "${UUID}" ]; then
        echo "正在生成随机 UUID ..."
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

    echo "SERV00PASSWORD='${SERV00PASSWORD}'" > ${WORKDIR}/.env
    cat >> ${WORKDIR}/.env << EOF
UUID=${UUID}
WSPATH=${WSPATH}
WEB_USERNAME=${WEB_USERNAME}
WEB_PASSWORD=${WEB_PASSWORD}
EOF
}

get_app() {
    echo "正在下载 app.js 请稍候..."
    wget -t 10 -qO ${WORKDIR}/app.js https://raw.githubusercontent.com/k0baya/x-for-serv00/direct/app.js
    if [ $? -ne 0 ]; then
        echo "app.js 下载失败！请检查网络情况！"
        exit 1
    fi
    echo "正在下载 package.json 请稍候..."
    wget -t 10 -qO ${WORKDIR}/package.json https://raw.githubusercontent.com/k0baya/x-for-serv00/direct/package.json
    if [ $? -ne 0 ]; then
        echo "package.json 下载失败！请检查网络情况！"
        exit 1
    fi
    echo "正在安装依赖，请稍候..."
    nohup npm22 install > /dev/null 2>&1
}

get_core() {
    local TMP_DIRECTORY=$(mktemp -d)
    local ZIP_FILE="${TMP_DIRECTORY}/Xray-freebsd-64.zip"
    echo "正在下载 Web.js 请稍候..."
    wget -t 10 -qO "$ZIP_FILE" https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip
    if [ $? -ne 0 ]; then
        echo "Web.js 下载失败！请检查网络情况！"
        exit 1
    else
        unzip -qo "$ZIP_FILE" -d "$TMP_DIRECTORY"
        install -m 755 "${TMP_DIRECTORY}/xray" "${WORKDIR}/web.js"
        rm -rf "$TMP_DIRECTORY"
    fi

    echo "正在下载 GEOSITE 数据库，请稍候..."
    wget -O ${WORKDIR}/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    if [ $? -ne 0 ]; then
        echo "GEOSITE 数据库下载失败！请检查网络情况！"
        exit 1
        
    echo "正在下载 GEOIP 数据库，请稍候..."
    wget -O ${WORKDIR}/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
    if [ $? -ne 0 ]; then
        echo "GEOIP 数据库下载失败！请检查网络情况！"
        exit 1
}

get_certificate() {
    local IP_ADDRESS=$(devil ssl www list | awk '/SNI SSL certificates for WWW/{flag=1; next} flag && NF && $6 != "address" {print $6}' | head -n 1)
    local DOMAIN=$(devil ssl www list | awk '/SNI SSL certificates for WWW/{flag=1; next} flag && NF && $6 != "address" {print $8}' | head -n 1)
    local MAINHOST=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^s')
    local SPAREHOST1=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^c')
    local SPAREHOST2=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^w')

    generate_certificate(){
        cat > cert.sh << EOF
#!/bin/bash
WORKDIR="${WORKDIR}"
IP_ADDRESS="${IP_ADDRESS}"
DOMAIN="${DOMAIN}"
SERV00PASSWORD="${SERV00PASSWORD}"
CERT_OUTPUT=\$(env SERV00PASSWORD="\${SERV00PASSWORD}" expect << ABC
spawn devil ssl www get "\${IP_ADDRESS}" "\${DOMAIN}"
expect "Password:"
send "\\\$env(SERV00PASSWORD)\r"
expect eof
catch wait result
puts "\nResult: \\\$result\n"
ABC
)
CERTIFICATE=\$(echo "\$CERT_OUTPUT" | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' ORS='\n')
PRIVATE_KEY=\$(echo "\$CERT_OUTPUT" | awk '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/' ORS='\n')
if [ -z "\${CERTIFICATE}" ] || [ -z "\${PRIVATE_KEY}" ]; then
    echo "证书获取失败，请检查是否在面板中成功获取到Let's Encrypt证书"
    exit 1
fi
[ -e \${WORKDIR}/cert.crt ] && rm -f \${WORKDIR}/cert.crt
[ -e \${WORKDIR}/private.key ] && rm -f \${WORKDIR}/private.key
echo "\$CERTIFICATE" > \${WORKDIR}/cert.crt
echo "\$PRIVATE_KEY" > \${WORKDIR}/private.key
killall -q web.js cloudflared
EOF
    chmod +x cert.sh
    bash cert.sh
    }

    [ ! -e ${WORKDIR}/cert.crt ] || [ ! -e ${WORKDIR}/private.key ] && generate_certificate

    export_list() {
        local MAINVMESS="{\"add\":\"${MAINHOST}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${PORT2}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        local SPAREVMESS1="{\"add\":\"${SPAREHOST1}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${PORT2}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        local SPAREVMESS2="{\"add\":\"${SPAREHOST2}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${PORT2}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        cat > ${WORKDIR}/list << EOF
*******************************************
        
Vless配置：

        
vless://${UUID}@${MAINHOST}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL


vless://${UUID}@${SPAREHOST1}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL


vless://${UUID}@${SPAREHOST2}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL

       
----------------------------
        
Vmess配置：
        

vmess://$(echo -n ${MAINVMESS} | base64 | tr -d '\n')


vmess://$(echo -n ${SPAREVMESS1} | base64 | tr -d '\n')


vmess://$(echo -n ${SPAREVMESS2} | base64 | tr -d '\n')

        
----------------------------
        
trojan配置：
        

trojan://${UUID}@${MAINHOST}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL


trojan://${UUID}@${SPAREHOST1}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL


trojan://${UUID}@${SPAREHOST2}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL

        
*******************************************
EOF

echo $(echo -n "vless://${UUID}@${MAINHOST}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL

vless://${UUID}@${SPAREHOST1}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL

vless://${UUID}@${SPAREHOST2}:${PORT1}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-reality-PL

vmess://$(echo -n ${MAINVMESS} | base64 | tr -d '\n')

vmess://$(echo -n ${SPAREVMESS1} | base64 | tr -d '\n')

vmess://$(echo -n ${SPAREVMESS2} | base64 | tr -d '\n')

trojan://${UUID}@${MAINHOST}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL

trojan://${UUID}@${SPAREHOST1}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL

trojan://${UUID}@${SPAREHOST2}:${PORT3}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL" | base64 ) > sub

  }
    export_list
}

set_language
set_domain_dir
reserve_port

cd ${WORKDIR}

[ ! -e ${WORKDIR}/.env ] && generate_dotenv
echo "正在检查依赖安装情况..."
[ -e ${WORKDIR}/.env ] && source ${WORKDIR}/.env
[ ! -e ${WORKDIR}/app.js ] || [ ! -e ${WORKDIR}/package.json ] && get_app
[ ! -e ${WORKDIR}/sing-box ] && get_core
echo "正在尝试生成配置..."
[ ! -e ${WORKDIR}/cert.crt ] || [ ! -e ${WORKDIR}/private.key ] || [ ! -e ${WORKDIR}/list ] && get_certificate
generate_config
[ -e ${WORKDIR}/cert.crt ] && [ -e ${WORKDIR}/private.key ] && [ -e ${WORKDIR}/list ] && echo "请访问 https://${USERNAME_DOMAIN}.serv00.net/status 获取服务端状态, 当 web.js 正常运行后，访问 https://${USERNAME_DOMAIN}.serv00.net/list 获取配置" && exit 0

echo "安装错误，请检查是否面板中放行了多余的 UDP 端口，检查自己的账号下是否至少有一个 Let's Encrypt 证书，检查密码是否输入正确，并重新尝试安装。"
