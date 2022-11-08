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

manage1(){
    green "请选择以下选项："
    echo -e " ${GREEN}1.${PLAIN} 安装/切换 Wgcf-WARP单栈模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装/切换 Wgcf-WARP单栈模式 ${YELLOW}(WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装/切换 Wgcf-WARP双栈模式 ${YELLOW}(WARP IPv4+IPv6)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 开启、关闭和重启 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    read -rp "请输入选项：" answer1
    case $answer1 in
        *) exit 1 ;;
    esac
}

manage2(){
    green "请选择以下选项："
    read -rp "请输入选项：" answer2
    case $answer2 in
        *) exit 1 ;;
    esac
}

manage3(){
    green "请选择以下选项："
    read -rp "请输入选项：" answer3
    case $answer3 in
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
        *) exit 1 ;;
    esac
}

menu(){
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
    read -rp "请输入选项：" answer
    case $answer in
        *) exit 1 ;;
    esac
}

menu