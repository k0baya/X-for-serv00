WSPATH=${WSPATH:-'serv00'}  # WS 路径前缀。(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMPORT=${VMPORT:-'3001'}
WEBPORT=${WEBPORT:-'3002'}

generate_config() {
    cat > config.json << EOF
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "inbounds": [
        {
            "port":${VMPORT},
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

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget https://cloudflared.bowring.uk/binaries/cloudflared-freebsd-latest.7z && 7z x cloudflared-freebsd-latest.7z && rm cloudflared-freebsd-latest.7z && mv -f ./temp/* ./cloudflared && rm -rf temp && chmod +x cloudflared
}

run() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    if [[ "\$ARGO_AUTH" =~ TunnelSecret ]]; then
      echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json
      cat > tunnel.yml << EOF
tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")
credentials-file: ~/xray/tunnel.json
protocol: http2

ingress:
  - hostname: \$ARGO_DOMAIN
    service: http://localhost:${VMPORT}
EOF
      cat >> tunnel.yml << EOF
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
      nohup ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml run 2>/dev/null 2>&1 &
    elif [[ "\$ARGO_AUTH" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      nohup ./cloudflared tunnel --edge-ip-version auto --protocol http2 run --token ${ARGO_AUTH} 2>/dev/null 2>&1 &
    fi
  else
    nohup ./cloudflared tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://localhost:${VMPORT} 2>/dev/null 2>&1 &
    sleep 12

    attempt_count=0
    max_attempts=10

    while [ -z "\$ARGO_DOMAIN" ] && [ \$attempt_count -lt \$max_attempts ]; do
      LOCALHOST=\$(sockstat -4 -l -P tcp | grep cloudflare | awk '
      {
          for (i=1; i<=NF; i++) {
              if (\$i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+\$/) {
                  print \$i
                  break
              }
          }
      }')
  
      if [ -n "\$LOCALHOST" ]; then
        ARGO_DOMAIN=\$(wget -qO- \$LOCALHOST/quicktunnel | jq -r '.hostname')
      fi
  
      if [ -z "\$ARGO_DOMAIN" ]; then
        sleep 2
        attempt_count=\$((attempt_count + 1))
      fi
    done

    if [ -z "\$ARGO_DOMAIN" ]; then
      echo "警告！当前 IP 创建 Cloudflare 临时隧道数量已超出每小时限制，请删除 ~/xray，并等待一小时后重试。或者尝试固定 Argo 隧道使用本仓库。" > list
      echo "Warning! The number of Cloudflare temporary tunnels created by the current IP has exceeded the hourly limit, please remove ~/xray and wait one hour before retrying." >> list
      rm -rf ~/xray/.*
      rm -rf ~/xray/*
    fi
  fi
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-k0baya-Vmess\", \"add\": \"alejandracaiccedo.com\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/${WSPATH}-vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vmess://\$(echo -n \${VMESS} | base64 | tr -d '\n')
小火箭:
----------------------------
vmess://$(echo -n "none:${UUID}@alejandracaiccedo.com:443" | base64 | tr -d '\n')?remarks=Argo-k0baya-Vmess&obfsParam=\${ARGO_DOMAIN}&path=/${WSPATH}-vmess?ed=2048&obfs=websocket&tls=1&peer=\${ARGO_DOMAIN}&alterId=0
*******************************************
Clash:
----------------------------
- {name: Argo-k0baya-Vmess, type: vmess, server: alejandracaiccedo.com, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess?ed=2048, headers: {Host: \${ARGO_DOMAIN}}}, udp: true}
*******************************************
EOF
  cat list
}

check_file
run
sleep 12 && [ -n "\$ARGO_DOMAIN" ] && export_list
ABC
}

generate_config
generate_argo

[ -e argo.sh ] && bash argo.sh
