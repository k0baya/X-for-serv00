WSPATH=${WSPATH:-'serv00'}  # WS 路径前缀。(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VLPORT=${VMPORT}
VMPORT=${WEBPORT}
TRPORT=${TRPORT}

USERNAME=$(whoami)
WORKDIR="/home/${USERNAME}/direct-xray"

generate_config(){
#     local XRAYKEY=$(${WORKDIR}/xray x25519 | grep '^Private' | awk '{print $3}')
    cat > ${WORKDIR}/config.json << EOF
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [
            {
                "listen": "0.0.0.0",
                "port": ${VLPORT},
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
                },
                "sniffing": {
                    "enabled": true,
                    "destOverride": [
                        "http",
                        "tls",
                        "quic"
                ],
                    "metadataOnly":false
            }
        },
        {
            "listen": "0.0.0.0",
            "port": ${VMPORT},  
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
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
        "port": ${TRPORT},  
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
        },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }        
    ],
    "dns": {
        "servers": [
            "https+local://1.1.1.1/dns-query",
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds": [
        {
            "protocol": "freedom"
        },
        {
            "tag": "WARP",
            "protocol": "wireguard",
            "settings": {
                "secretKey": "YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
                "address": [
                    "172.16.0.2/32",
                    "2606:4700:110:8a36:df92:102a:9602:fa18/128"
                ],
                "peers": [
                    {
                        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "allowedIPs": [
                            "0.0.0.0/0",
                            "::/0"
                        ],
                        "endpoint": "162.159.193.10:2408"
                    }
                ],
                "reserved": [78, 135, 76],
                "mtu": 1280
            }
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "outboundTag": "WARP",
                "domain":[
                    "domain:openai.com",
                    "domain:chatgpt.com",
                    "domain:ai.com",
                    "domain:netflix.com"
                ]
            },
            {
                "type": "field",
                "outboundTag": "WARP",
                "ip": [
                    "::/0"
                ]
            }
        ]
    }
}
EOF
}

get_port(){
    numbers=$(devil port list | awk '$1 ~ /^[0-9]+$/ {print $1}')
    numbers_array=($numbers)
    count=${#numbers_array[@]}
    if [ "$count" -eq 3 ]; then
        VLPORT=${numbers_array[0]}
        VMPORT=${numbers_array[1]}
        TRPORT=${numbers_array[2]}
    else
    echo "请检查端口开放情况，当前并未获取到三个端口！" > ${WORKDIR}/list
    exit 1
    fi
}

get_certificate() {
    local IP_ADDRESS=$(devil ssl www list | awk '/SNI SSL certificates for WWW/{flag=1; next} flag && NF && $6 != "address" {print $6}' | head -n 1)
    local DOMAIN=$(devil ssl www list | awk '/SNI SSL certificates for WWW/{flag=1; next} flag && NF && $6 != "address" {print $8}' | head -n 1)
    local MAINHOST=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^s')
    local SPAREHOST1=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^c')
    local SPAREHOST2=$(devil vhost list | awk 'NR>1 {print $2}' | grep '^w')

    generate_certificate(){
    local CERT_OUTPUT=$(env SERV00PASSWORD="$SERV00PASSWORD" expect << EOF
spawn devil ssl www get "${IP_ADDRESS}" "${DOMAIN}"
expect "Password:"
send "\$env(SERV00PASSWORD)\r"
expect eof
catch wait result
puts "\nResult: \$result\n"
EOF
)
    local CERTIFICATE=$(echo "$CERT_OUTPUT" | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' ORS='\n')
    local PRIVATE_KEY=$(echo "$CERT_OUTPUT" | awk '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/' ORS='\n')
    if [ -z "${CERTIFICATE}" ] || [ -z "${PRIVATE_KEY}" ]; then
        echo "证书获取失败，请检查是否在面板中成功获取到Let's Encrypt证书" > ${WORKDIR}/list
        exit 1
    fi
    echo "$CERTIFICATE" > ${WORKDIR}/cert.crt
    echo "$PRIVATE_KEY" > ${WORKDIR}/private.key
    }

    [ ! -e ${WORKDIR}/cert.crt ] || [ ! -e ${WORKDIR}/private.key ] && generate_certificate

    export_list() {
        local MAINVMESS="{\"add\":\"${MAINHOST}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${VMPORT}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        local SPAREVMESS1="{\"add\":\"${SPAREHOST1}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${VMPORT}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        local SPAREVMESS2="{\"add\":\"${SPAREHOST2}\",\"aid\":\"0\",\"alpn\":\"\",\"fp\":\"\",\"host\":\"${DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${WSPATH}-vmess?ed=2560\",\"port\":\"${VMPORT}\",\"ps\":\"🇵🇱Vm-k0baya-tls-ws-PL\",\"scy\":\"aes-128-gcm\",\"sni\":\"${DOMAIN}\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
        cat > ${WORKDIR}/list << EOF
*******************************************
        
Vless配置：

        
vless://${UUID}@${MAINHOST}:${VLPORT}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-PL


vless://${UUID}@${SPAREHOST1}:${VLPORT}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-PL


vless://${UUID}@${SPAREHOST2}:${VLPORT}?security=reality&encryption=none&pbk=G0LAF0i9NRrHpAWbnrjYyLQ86o0PfeJDDQ5hm_73Mkk&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.serv00.com&sid=ff04#🇵🇱Vl-k0baya-xtls-vision-PL

       
----------------------------
        
Vmess配置：
        

vmess://$(echo -n ${MAINVMESS} | base64 | tr -d '\n')


vmess://$(echo -n ${SPAREVMESS1} | base64 | tr -d '\n')


vmess://$(echo -n ${SPAREVMESS2} | base64 | tr -d '\n')

        
----------------------------
        
trojan配置：
        

trojan://${UUID}@${MAINHOST}:${TRPORT}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL


trojan://${UUID}@${SPAREHOST1}:${TRPORT}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL


trojan://${UUID}@${SPAREHOST2}:${TRPORT}?security=tls&headerType=none&type=tcp&sni=${DOMAIN}#🇵🇱Tr-k0baya-tls-PL

        
*******************************************
EOF
  }
    export_list
}

get_xray(){
    mkdir -p tmp \
    && cd tmp \
    && wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-freebsd-64.zip \
    && unzip Xray-freebsd-64.zip \
    && cd .. \
    && mv -f ./tmp/xray ./web.js \
    && rm -rf tmp \
    && chmod +x web.js
}

mkdir -p ${WORKDIR}
cd ${WORKDIR}
[ -z "$VLPORT" ] || [ -z "$VMPORT" ] || [ -z "$TRPORT" ] && get_port
[ ! -e ${WORKDIR}/web.js ] && get_xray
generate_config
get_certificate
exec ${WORKDIR}/web.js -c ${WORKDIR}/config.json