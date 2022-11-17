#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "目前脚本暂未支持 ${SYS} 系统！" && exit 1

wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf"
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"
# Wgcf Endpoint
wg3="sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' /etc/wireguard/wgcf.conf"
# Wgcf DNS Servers
wg5="sed -i 's/1.1.1.1/1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg6="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"
# Wgcf 允许外部IP地址
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg8='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg9='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'

main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
VERID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
VIRT=$(systemd-detect-virt)
TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')

if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "脚本暂不不支持 $(uname -m) 架构!" && exit 1 ;;
    esac
}

if [[ ! -f /usr/local/bin/nf ]]; then
    wget https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/netflix-verify/nf-linux-$(archAffix) -O /usr/local/bin/nf
    chmod +x /usr/local/bin/nf
fi

checkstack(){
    lan4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    lan6=$(ip route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+')
    if [[ "$lan4" =~ ^([0-9]{1,3}\.){3} ]]; then
        ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && out4=1
    fi
    if [[ "$lan6" != "::1" && "$lan6" =~ ^([a-f0-9]{1,4}:){2,4}[a-f0-9]{1,4} ]]; then
        ping6 -c2 -w10 2606:4700:4700::1111 >/dev/null 2>&1 && out6=1
    fi
}

checkwarp(){
    warpv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warpv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

checkmtu(){
    yellow "正在检测并设置MTU最佳值, 请稍等..."
    checkv4v6
    MTUy=1500
    MTUc=10
    if [[ -n ${v6} && -z ${v4} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    MTU=$((${MTUy} - 80))
    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
    green "MTU 最佳值=$MTU 已设置完毕"
}

checktun(){
    if [[ ! $TUN =~ "in bad state"|"处于错误状态"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/tun.sh && bash tun.sh
        else
            red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
            exit 1
        fi
    fi
}

checkv4v6(){
    ipv4=$(curl -s4m8 api.ipify.org)
    ipv6=$(curl -s6m8 api64.ipify.org)
}

initwgcf(){
    wget -N --no-check-certificate https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/wgcf/wgcf-latest-linux-$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

wgcfreg(){
    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
    fi

    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待脚本重试注册即可"
        wgcf register --accept-tos
        sleep 5
    done
    chmod +x wgcf-account.toml

    wgcf generate
    chmod +x wgcf-profile.conf
}

wgcfv4(){
    checkwarp
    if [[ $warpv4 =~ on|plus ]] || [[ $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkstack
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkstack
    fi

    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4)"
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg3
            switchconf
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4)"
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg3
            installwgcf
        fi
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6 && wgcf2=$wg2 && wgcf3=$wg4
            switchconf
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6 && wgcf2=$wg2 && wgcf3=$wg4
            installwgcf
        fi
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2
            switchconf
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2
            installwgcf
        fi
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg4
            switchconf
        else
            yellow "检测为NAT IPv4+原生IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
            wgcf1=$wg6 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg4
            installwgcf
        fi
    fi
}

wgcfv6(){
    checkwarp
    if [[ $warpv4 =~ on|plus ]] || [[ $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkstack
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkstack
    fi

    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"           
            wgcf1=$wg5 && wgcf2=$wg1 && wgcf3=$wg3
            switchconf
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"
            wgcf1=$wg5 && wgcf2=$wg1 && wgcf3=$wg3
            installwgcf
        fi
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv6)"            
            wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg1 && wgcf4=$wg4
            switchconf
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
            wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg1 && wgcf4=$wg4
            installwgcf
        fi
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"            
            wgcf1=$wg5 && wgcf2=$wg8 && wgcf3=$wg1
            switchconf
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
            wgcf1=$wg5 && wgcf2=$wg8 && wgcf3=$wg1
            installwgcf
        fi
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv6)"            
            wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg1 && wgcf4=$wg4
            switchconf
        else
            yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
            wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg1 && wgcf4=$wg4
            installwgcf
        fi
    fi
}

wgcfv46(){
    checkwarp
    if [[ $warpv4 =~ on|plus ]] || [[ $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkstack
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkstack
    fi

    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"            
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg3
            switchconf
        else
            yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg3
            installwgcf
        fi
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"            
            wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg4
            switchconf
        else
            yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg4
            installwgcf
        fi
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + WARP IPv6)"            
            wgcf1=$wg5 && wgcf2=$wg9
            switchconf
        else
            yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg5 && wgcf2=$wg9
            installwgcf
        fi
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"           
            wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg4
            switchconf
        else
            yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
            wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg4
            installwgcf
        fi
    fi
}

wgcfconf(){
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
    echo $wgcf4 | sh
}

installwgcf(){
    checktun

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/wireguard-go/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    initwgcf
    wgcfreg
    checkmtu

    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi
    
    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf >/dev/null 2>&1
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml >/dev/null 2>&1

    wgcfconf
    checkwgcf
}

switchconf(){
    wg-quick down wgcf >/dev/null 2>&1

    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf

    wgcfconf
    checkwgcf
}

checkwgcf(){
    yellow "正在启动 Wgcf-WARP"
    i=0
    while [ $i -le 4 ]; do let i++
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        checkwarp
        if [[ $warpv4 =~ on|plus ]] || [[ $warpv6 =~ on|plus ]]; then
            systemctl enable wg-quick@wgcf >/dev/null 2>&1
            green "Wgcf-WARP 已启动成功！"
            break
        else
            red "Wgcf-WARP 启动失败！"
        fi
        checkwarp
        if [[ ! $warpv4 =~ on|plus && ! $warpv6 =~ on|plus ]]; then
            red "安装Wgcf-WARP失败！"
            green "建议如下："
            yellow "1. 建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分VPS系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看https://www.cloudflarestatus.com/，如当前VPS区域可能处于【Re-routed】状态时，代表你的VPS无法使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
            exit 1
        fi
    done
}

switchwgcf(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 重启 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} 启动 Wgcf-WARP"
    echo -e " ${GREEN}3.${PLAIN} 停止 Wgcf-WARP"
    read -rp "请输入选项：" answerwgcf
    if [[ $answerwgcf == 1 ]]; then
        checkwgcf
    elif [[ $answerwgcf == 2 ]]; then
        checkwgcf
    elif [[ $answerwgcf == 3 ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        green "Wgcf-WARP 已停止成功！"
    fi
}

unstwgcf(){
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null
    ${PACKAGE_UNINSTALL[int]} wireguard-tools wireguard-dkms
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-account.toml
    fi
    rm -f /etc/wireguard/wgcf.conf
    rm -f /usr/bin/wireguard-go
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi
    green "Wgcf-WARP 已彻底卸载成功!"
}

installcli(){
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${VERID} =~ 8 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 8系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${VERID} =~ 9|10|11 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Debian 9-11系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && yellow "当前系统版本：${CMD} \nWARP-Cli暂时不支持Fedora系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${VERID} =~ 16|18|20|22 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Ubuntu 16.04/18.04/20.04/22.04系统" && exit 1
    
    [[ ! $(archAffix) == "amd64" ]] && red "WARP-Cli暂时不支持目前VPS的CPU架构, 请使用CPU架构为amd64的VPS" && exit 1
    
    checktun

    checkwarp
    if [[ $warpv4 =~ on|plus ]] ||[[ $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkv4v6
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkv4v6
    fi

    if [[ -z $v4 ]]; then
        red "WARP-Cli暂时不支持纯IPv6的VPS，退出安装！"
        exit 1
    fi
    
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools bc htop iputils screen python3 qrencode
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    warp-cli --accept-tos register >/dev/null 2>&1
    if [[ $warpcli == 1 ]]; then
        yellow "正在启动 WARP-Cli IPv4网卡出口模式"
        warp-cli --accept-tos add-excluded-route 0.0.0.0/0 >/dev/null 2>&1
        warp-cli --accept-tos add-excluded-route ::0/0 >/dev/null 2>&1
        warp-cli --accept-tos set-mode warp >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        sleep 5
        ip -4 rule add from 172.16.0.2 lookup 51820
        ip -4 route add default dev CloudflareWARP table 51820
        ip -4 rule add table main suppress_prefixlength 0
        IPv4=$(curl -s4m8 api.ipify.org --interface CloudflareWARP)
        retry_time=0
        until [[ -n $IPv4 ]]; do
            retry_time=$((${retry_time} + 1))
            red "启动 WARP-Cli IPv4网卡出口模式失败，正在尝试重启，重试次数：$retry_time"
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            warp-cli --accept-tos disable-always-on >/dev/null 2>&1
            ip -4 rule delete from 172.16.0.2 lookup 51820
            ip -4 rule delete table main suppress_prefixlength 0
            sleep 2
            warp-cli --accept-tos connect >/dev/null 2>&1
            warp-cli --accept-tos enable-always-on >/dev/null 2>&1
            sleep 5
            ip -4 rule add from 172.16.0.2 lookup 51820
            ip -4 route add default dev CloudflareWARP table 51820
            ip -4 rule add table main suppress_prefixlength 0
            if [[ $retry_time == 6 ]]; then
                warp-cli --accept-tos disconnect >/dev/null 2>&1
                warp-cli --accept-tos disable-always-on >/dev/null 2>&1
                ip -4 rule delete from 172.16.0.2 lookup 51820
                ip -4 rule delete table main suppress_prefixlength 0
                uninstallcli
                red "由于WARP-Cli IPv4网卡出口模式启动重试次数过多 ,已自动卸载WARP-Cli IPv4网卡出口模式"
                green "建议如下："
                yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
                yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
                exit 1
            fi
        done
        green "WARP-Cli IPv4网卡出口模式已安装成功！"
    fi

    if [[ $warpcli == 2 ]]; then
        read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
        [[ -z $WARPCliPort ]] && WARPCliPort=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                    yellow "你设置的端口目前已被占用，请重新输入端口"
                    read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
                fi
            done
        fi
        yellow "正在启动 WARP-Cli 代理模式"
        warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
        warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        sleep 2
        if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
            red "由于WARP-Cli代理模式安装失败 ,已自动卸载WARP-Cli代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
            exit 1
        else
            green "WARP-Cli 代理模式已启动成功!"
        fi
    fi
}

warpcli_changeport() {
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
    fi
    
    read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WARPCliPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WARP-Cli使用的代理端口 (默认随机端口): " WARPCliPort
            fi
        done
    fi
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
    
    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    
    if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
        red "WARP-Cli代理模式启动失败！"
        exit 1
    else
        green "WARP-Cli代理模式已启动成功并成功修改代理端口！"
    fi
}

switchcli(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 重启 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} 启动 Wgcf-WARP"
    echo -e " ${GREEN}3.${PLAIN} 停止 Wgcf-WARP"
    read -rp "请输入选项：" answerwgcf
    if [[ $answerwgcf == 1 ]]; then
        yellow "正在重启Warp-Cli"
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        green "WARP-Cli客户端已重启成功! "
    elif [[ $answerwgcf == 2 ]]; then
        yellow "正在启动Warp-Cli"
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        green "WARP-Cli客户端已启动成功! "
    elif [[ $answerwgcf == 3 ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        green "WARP-Cli客户端已停止成功！"
    fi
}

uninstallcli(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp
    systemctl disable --now warp-svc >/dev/null 2>&1
    green "WARP-Cli客户端已彻底卸载成功!"
}

installWireProxy(){
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode
    fi
    
    wget https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/wireproxy/wireproxy-latest-linux-$(archAffix) -O /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy
    
    initwgcf
    wgcfreg
    
    checkwarp
    
    if [[ $warpv4 =~ on|plus ]] || [[ $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        checkmtu
        checkv4v6
        wg-quick up wgcf >/dev/null 2>&1
    else
        checkmtu
        checkv4v6
    fi
    
    read -rp "请输入WireProxy-WARP使用的代理端口 (默认随机端口): " WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$WireProxyPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WireProxy-WARP使用的代理端口 (默认随机端口): " WireProxyPort
            fi
        done
    fi
    
    WgcfPrivateKey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
    WgcfPublicKey=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    
    if [[ -z $ipv4 && -n $ipv6 ]]; then
        WireproxyEndpoint="[2606:4700:d0::a29f:c001]:2408"
    else
        WireproxyEndpoint="162.159.193.10:2408"
    fi

    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi

    cat <<EOF > /etc/wireguard/proxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = $MTU
PrivateKey = $WgcfPrivateKey
DNS = 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844
[Peer]
PublicKey = $WgcfPublicKey
Endpoint = $WireproxyEndpoint
[Socks5]
BindAddress = 127.0.0.1:$WireProxyPort
EOF
    
    cat <<'TEXT' > /etc/systemd/system/wireproxy-warp.service
[Unit]
Description=CloudFlare WARP Socks5 proxy mode based for WireProxy, script by mikupeto
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/bin/wireproxy -c /etc/wireguard/proxy.conf
Restart=always
TEXT
    
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 WireProxy-WARP 代理模式"
    systemctl start wireproxy-warp
    WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    sleep 2
    retry_time=0
    until [[ $WireProxyStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            uninstallWireProxy
            echo ""
            red "由于 WireProxy-WARP 代理模式启动重试次数过多 ,已自动卸载 WireProxy-WARP 代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/ 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用WireProxy-WARP 代理模式"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
            exit 1
        fi
        sleep 8
    done
    sleep 5
    systemctl enable wireproxy-warp >/dev/null 2>&1
    green "WireProxy-WARP 代理模式已启动成功!"
    echo ""
    showIP
}

wireproxy_changeport(){
    systemctl stop wireproxy-warp
    read -rp "请输入WireProxy-WARP使用的代理端口 (默认随机端口): " WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(netstat -ntlp | grep "$WireProxyPort") ]]; then
        until [[ -z $(netstat -ntlp | grep "$WireProxyPort") ]]; do
            if [[ -n $(netstat -ntlp | grep "$WireProxyPort") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入WireProxy-WARP使用的代理端口 (默认随机端口): " WireProxyPort
            fi
        done
    fi
    CurrentPort=$(grep BindAddress /etc/wireguard/proxy.conf)
    sed -i "s/$CurrentPort/BindAddress = 127.0.0.1:$WireProxyPort/g" /etc/wireguard/proxy.conf
    yellow "正在启动 WireProxy-WARP 代理模式"
    systemctl start wireproxy-warp
    WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    retry_time=0
    until [[ $WireProxyStatus =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        WireProxyStatus=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            uninstallWireProxy
            echo ""
            red "由于 WireProxy-WARP 代理模式启动重试次数过多 ,已自动卸载 WireProxy-WARP 代理模式"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/ 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用WireProxy-WARP 代理模式"
            yellow "4. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
            exit 1
        fi
        sleep 8
    done
    systemctl enable wireproxy-warp
    green "WireProxy-WARP 代理模式已启动成功并已修改端口！"
    echo ""
    showIP
}

switchWireproxy(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 重启 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} 启动 Wgcf-WARP"
    echo -e " ${GREEN}3.${PLAIN} 停止 Wgcf-WARP"
    read -rp "请输入选项：" answerwgcf
    if [[ $answerwgcf == 1 ]]; then
        yellow "正在重启WireProxy-WARP"
        systemctl restart wireproxy-warp
        green "WireProxy-WARP客户端已重启成功!"
    elif [[ $answerwgcf == 2 ]]; then
        yellow "正在启动WireProxy-WARP"
        systemctl start wireproxy-warp
        systemctl enable wireproxy-warp
        green "WireProxy-WARP客户端已启动成功!"
    elif [[ $answerwgcf == 3 ]]; then
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        green "WireProxy-WARP客户端已停止成功！"
    fi
}

uninstallWireProxy(){
    systemctl stop wireproxy-warp
    systemctl disable wireproxy-warp
    rm -f /etc/systemd/system/wireproxy-warp.service /usr/local/bin/wireproxy /etc/wireguard/proxy.conf
    if [[ ! -f /etc/wireguard/wgcf.conf ]]; then
        rm -f /usr/local/bin/wgcf /etc/wireguard/wgcf-account.toml
    fi
    green "WireProxy-WARP代理模式已彻底卸载成功!"
}


wgfile(){
    yellow "请选择将要生成的配置文件的网络环境："
    green "1. IPv4 （默认）"
    green "2. IPv6"
    read -rp "请输入选项 [1-2]：" netInput
    case $netInput in
        1) endpointip="162.159.193.10" ;;
        2) endpointip="[2606:4700:d0::]" ;;
        *) endpointip="162.159.193.10" ;;
    esac
    cp -f /etc/wireguard/wgcf.conf /root/wgcf-proxy.conf
    sed -i "10a Endpoint = $endpointip:1701" /root/wgcf-proxy.conf
    green "Wgcf-WARP的WireGuard配置文件已提取成功！"
    yellow "文件已保存至：/root/wgcf-proxy.conf"
    yellow "WireGuard 节点配置二维码如下所示："
    qrencode -t ansiutf8 < /root/wgcf-proxy.conf
}

warpup(){
    yellow "获取CloudFlare WARP账号信息方法: "
    green "电脑: 下载并安装CloudFlare WARP→设置→偏好设置→复制设备ID到脚本中"
    green "手机: 下载并安装1.1.1.1 APP→菜单→高级→诊断→复制设备ID到脚本中"
    echo ""
    yellow "请按照下面指示, 输入您的CloudFlare WARP账号信息:"
    read -rp "请输入您的WARP设备ID (36位字符): " license
    until [[ $license =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
        red "设备ID输入格式输入错误，请重新输入！"
        read -rp "请输入您的WARP设备ID (36位字符): " license
    done
    wget -N --no-check-certificate https://cdn.jsdelivr.net/gh/mikupeto/warp-script/files/wp-plus.py
    sed -i "27 s/[(][^)]*[)]//g" wp-plus.py
    sed -i "27 s/input/'$license'/" wp-plus.py
    read -rp "请输入Screen会话名称 (默认为wp-plus): " screenname
    [[ -z $screenname ]] && screenname="wp-plus"
    screen -UdmS $screenname bash -c '/usr/bin/python3 /root/wp-plus.py'
    green "创建刷WARP+流量任务成功！ Screen会话名称为：$screenname"
}

manage1(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 安装/切换 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装/切换 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装/切换 Wgcf-WARP 双栈模式"
    echo -e " ${GREEN}4.${PLAIN} 开启、关闭和重启 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    read -rp "请输入选项：" answer1
    case $answer1 in
        1) wgcfv4 ;;
        2) wgcfv6 ;;
        3) wgcfv46 ;;
        4) switchwgcf ;;
        5) unstwgcf ;;
        *) exit 1 ;;
    esac
}

manage2(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 安装 WARP-Cli 并添加IPv4网卡出口"
    echo -e " ${GREEN}2.${PLAIN} 安装 WARP-Cli 并创建本地Socks5代理"
    echo -e " ${GREEN}3.${PLAIN} 修改 WARP-Cli 本地Socks5代理端口"
    echo -e " ${GREEN}4.${PLAIN} 开启、关闭和重启 WARP-Cli"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 WARP-Cli${PLAIN}"
    read -rp "请输入选项：" answer2
    case $answer2 in
        1) warpcli=1 && installcli ;;
        2) warpcli=2 && installcli ;;
        3) warpcli_changeport ;;
        4) switchcli ;;
        5) uninstallcli ;;
        *) exit 1 ;;
    esac
}

manage3(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 安装 WireProxy-WARP 并创建本地Socks5代理"
    echo -e " ${GREEN}2.${PLAIN} 修改 WireProxy-WARP 本地Socks5代理端口"
    echo -e " ${GREEN}3.${PLAIN} 开启、关闭和重启 WireProxy-WARP"
    echo -e " ${GREEN}4.${PLAIN} ${RED}卸载 WireProxy-WARP${PLAIN}"
    read -rp "请输入选项：" answer3
    case $answer3 in
        1) installWireProxy ;;
        2) wireproxy_changeport ;;
        3) switchWireproxy ;;
        4) uninstallWireProxy ;;
        *) exit 1 ;;
    esac
}

manage4(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 提取WireGuard配置文件"
    echo -e " ${GREEN}2.${PLAIN} WARP+账户刷流量"
    echo -e " ${GREEN}3.${PLAIN} 切换WARP账户"
    echo -e " ${GREEN}4.${PLAIN} 获取解锁NF的WARP IP"
    read -rp "请输入选项：" answer4
    case $answer4 in
        1) wgfile ;;
        2) warpup ;;
        *) exit 1 ;;
    esac
}

check_status(){
    yellow "正在获取VPS配置信息，请稍等..."
    checkwarp
    
    [[ $warpv4 == off ]] && stat4="Normal"
    [[ $warpv6 == off ]] && stat6="Normal"
    [[ $warpv4 == on ]] && stat4="${YELLOW}WARP${PLAIN}"
    [[ $warpv6 == on ]] && stat6="${YELLOW}WARP${PLAIN}"
    [[ $warpv4 == plus ]] && stat4="${GREEN}WARP+${PLAIN}"
    [[ $warpv6 == plus ]] && stat6="${GREEN}WARP+${PLAIN}"

    if [[ -n $(type -P warp-cli) ]]; then
        if [[ $(warp-cli --accept-tos settings 2>/dev/null | grep "Mode" | awk -F ": " '{print $2}') == "Warp" ]]; then
            statc=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k --interface CloudflareWARP | grep warp | cut -d= -f2)
        else
            sockport=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
            statc=$(curl -sx socks5h://localhost:$sockport https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        fi
    fi

    if [[ -n $(type -P wireproxy) ]]; then
        sockport=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
        statp=$(curl -sx socks5h://localhost:$sockport https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    fi

    [[ -z $statc ]] && statc="${RED}Not Installed${PLAIN}"
    [[ -z $statp ]] && statc="${RED}Not Installed${PLAIN}"
}

show_status(){
    echo  " -------------------- "
    echo -e "IPv4: $stat4"
    echo -e "IPv6: $stat6"
    echo -e "WARP-Cli: $statc"
    echo -e "WireProxy: $statp"
    echo  " -------------------- "
}

menu(){
    check_status
    clear
    yellow " CloudFlare WARP 一键脚本 "
    yellow "      by Mikupeto"
    echo ""
    echo  " ---------------------- "
    echo -e " ${GREEN}1.${PLAIN} 管理 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} 管理 WARP-Cli"
    echo -e " ${GREEN}3.${PLAIN} 管理 WireProxy-WARP"
    echo -e " ${GREEN}4.${PLAIN} WARP 脚本小工具"
    echo  " -------------------- "
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    show_status
    echo ""
    read -rp "请输入选项：" answer
    case $answer in
        1) manage1 ;;
        2) manage2 ;;
        3) manage3 ;;
        4) manage4 ;;
        *) exit 1 ;;
    esac
}

menu