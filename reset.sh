#!/usr/bin/bash
delete_all_domains() {
    domain_list=$(devil www list | awk 'NR>2 {print $1}')
    
    if [ -z "$domain_list" ]; then
        echo "没有找到任何域名。"
        return
    fi
    
    for domain in $domain_list; do
        echo "删除域名: $domain"
        devil www del "$domain"
    done
}

delete_all_ports() {
    port_list=$(devil port list | awk 'NR>2 {print $1, $2}')
    
    if [ -z "$port_list" ]; then
        echo "没有找到任何端口。"
        return
    fi
    
    while read -r port type; do
        if [ -n "$port" ] && [ -n "$type" ]; then
            echo "删除端口: $type $port"
            devil port del "$type" "$port"
        fi
    done <<< "$port_list"
}

reset_user() {
    echo "正在删除全部文件..."
    nohup chmod -R 755 ~/.* > /dev/null 2>&1
    nohup chmod -R 755 ~/* > /dev/null 2>&1
    nohup rm -rf ~/.* > /dev/null 2>&1
    nohup rm -rf ~/* > /dev/null 2>&1
    
    echo "重置完成！"
    devil lang set english
    killall -u $(whoami)
}

delete_all_domains
delete_all_ports
reset_user
