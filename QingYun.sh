#!/bin/bash
# Date: 2021-08-18
# Author: JiangShan.
# Description: 
#一键分区
#一键扩容
#用法：bash homeV31.sh
# Version: 1.0.20210818
# 轻云互联 qingyunl.com


rsname=QingYun #shell名称
LOCKfile=/root/.$(basename $0).lock
LOGfile=/root/.$(basename $0).log

Echo()
{
	case $1 in
	    success)  flag="\033[1;32m"
	    ;;
	    failure)  flag="\033[1;31m"
	    ;;
	    warning)  flag="\033[1;33m"
	    ;;
	    msg)  flag="\033[1;34m"
	    ;;
	    *)  flag="\033[1;34m"
	    ;;
	esac
	if [[ $LANG =~ [Uu][Tt][Ff] ]]
	then
		echo -e "${flag}${2}\033[0m"
	else
		echo -e "${flag}${2}\033[0m" | iconv -f utf-8 -t gbk
	fi
	#写日志
	[ "${3}A" == "LogA" ] && Shell_log $2
        echo
}

Shell_log(){
    LOG_INFO=$1
    Echo "msg" "$(date "+%Y-%m-%d") $(date "+%H:%M:%S"):$rsname:$LOG_INFO" >> $LOGfile
}

Shell_lock(){
    touch $LOCKfile
}
Shell_unlock(){
    rm -f $LOCKfile
}
Exit(){
	Shell_unlock
	exit
}

CheckWDCP()
{
        # wdcp 相关服务启停
	service httpd $1
	service nginxd $1
	service mysqld $1
	service pureftpd $1
	[ -e /etc/init.d/wdcp ] && service wdcp $1
	[ -e /etc/init.d/wdapache ] && service wdapache $1
	[ -e /etc/init.d/redis_6379 ] && service redis_6379 $1
	[ -e /etc/init.d/memcached ] && service memcached $1
}

CheckBT()
{
	# bt 相关服务启停
	service bt $1
	[ -e /etc/init.d/httpd ] && service httpd $1
	[ -e /etc/init.d/mysqld ] && service mysqld $1
	[ -e /etc/init.d/nginx ] && service nginx $1
	[ -e /etc/init.d/redis ] && service redis $1
	[ -e /etc/init.d/tomcat ] && service tomcat $1
        [ -e /etc/init.d/tomcat7 ] && /etc/init.d/tomcat7 start
	[ -e /etc/init.d/memcached ] && service memcached $1
	[ -e /etc/init.d/pure-ftpd ] && service pure-ftpd $1
	[ -e /etc/init.d/php-fpm-53 ] && service php-fpm-52 $1
	[ -e /etc/init.d/php-fpm-53 ] && service php-fpm-53 $1
	[ -e /etc/init.d/php-fpm-54 ] && service php-fpm-54 $1
	[ -e /etc/init.d/php-fpm-55 ] && service php-fpm-55 $1
	[ -e /etc/init.d/php-fpm-56 ] && service php-fpm-56 $1
	[ -e /etc/init.d/php-fpm-70 ] && service php-fpm-70 $1
	[ -e /etc/init.d/php-fpm-71 ] && service php-fpm-71 $1
	[ -e /etc/init.d/php-fpm-72 ] && service php-fpm-72 $1
	[ -e /etc/init.d/php-fpm-73 ] && service php-fpm-73 $1
	[ -e /etc/init.d/php-fpm-74 ] && service php-fpm-74 $1
    [ -e /etc/init.d/php-fpm-80 ] && service php-fpm-80 $1
}

Auto()
{
	tempdev=`ls /dev/vd[b-z]`
	Echo "msg" "请输入设备名,比如以下设备名,扩容数据盘/dev/vdb请直接回车" "Log"
	Echo "msg" "$tempdev" "Log"
	read -p ":" devpart
	[ -z "$devpart" ] && devpart="/dev/vdb"
	while [[ ! -e "$devpart" ]] 
	do
		Echo "warning" "输入设备名错误,请重新输入" "Log"
		read -p ":" devpart
	done
	data_part=`df -vh |grep ${devpart}1|awk '{print $6}'`
	Swap=`free -m | awk '/Swap:/{print $2}'`
	Swapdir=$(cat /etc/fstab |grep swap|awk '{print $1}')
	[ "$Swap" -ne '0' ] && swapoff $Swapdir	
    [ -d /www/server/panel ] && Echo "msg" "预装BT面板系统,正在停止BT相关服务。"  "Log"&& CheckBT stop
	which fuser >/dev/null 2>&1
	[ $? -ne 0 ] && yum -y install psmisc fuser
	Echo "msg" "开始杀掉访问home文件的进程。" "Log"
	fuser -m $data_part -k
	sleep 5
        fuser -v $data_part
	Echo "msg" "开始取消home挂载。" "Log"
	umount $data_part
	if [ $? -ne 0 ] ;then
		Echo "warning" "取消$data_part挂载失败,程序自动退出,请手动操作扩展" "Log"
		[ -d /www/wdlinux/wdcp ] && CheckWDCP start
                [ -d /www/server/panel ] && CheckBT start
		Exit
	fi
        df -vh
	Echo "msg" "开始扩容,如果硬盘较大,时间可能会很长,请耐心等待" "Log"
	Startflag=`parted $devpart print|sed -n '/primary/p'|awk '{print $2}'`
	parted $devpart print|grep primary > /parted.txt
	[ ! -e /parted.txt ] && Echo "warning" "备份分区表文件不成功,程序自动退出,请手动操作扩展" "Log"
	parted $devpart  rm 1
	yes|parted $devpart  mkpart primary $Startflag 100%
	[ $? -ne 0 ] && Echo "warning" "分区扩容失败，请手动操作扩展" "Log" && Exit
	Echo "msg" "开始调整文件系统大小。"
	resize2fs -f ${devpart}1
	Echo "msg" "开始挂载分区。"
	mount -a
	[ "$Swap" -ne '0' ] && swapon $Swapdir	
	[ -d /www/server/panel ] && Echo "msg" "预装BT面板系统,正在启动BT相关服务" "Log" && CheckBT start
	df -vh
	Echo "success" "$devpart扩容成功" "Log"
    Echo "success" "感谢您使用轻云互联" "Log"
	Exit
}

Main()
{
	if [ -e "/dev/vdc" ] ;then 
		for devname in `ls /dev/vd[c-z]`
		do
			if [ -e "$devname" ] && [ ! -e "${devname}1" ] ;then
				YunPanMBR $devname
			fi
		done
	fi
	Echo "msg" "是否需要扩容磁盘" "Log"
	read -p "[y/n]: " autodisk
	while [[ ! $autodisk =~ ^[y,n]$ ]] 
	do
		Echo "warning" "输入错误,只能输入y或n" "Log"
		read -p "[y/n]: " autodisk
	done
	if [ "$autodisk" == 'y' ];then
		Auto
	fi
}
if [ -f "$LOCKfile" ];then
	Echo "warning" "核实脚本正在运行中，请勿重复运行，若是之前强行中断引起的，请手工清理$LOCKfile" "Log" && exit
else
	Echo "msg" "首次运行脚本，将自动创建锁文件然后继续，避免在执行中重复运行脚本。" "Log"
	Shell_lock
fi
Main
Exit
