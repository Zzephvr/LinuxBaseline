#! /bin/bash
fail=0
pass=0
manual=0
separator="------------------------------------------------------"
check_pass(){
echo -e "\033[42;30m [++]PASS \033[0m"          #成功打印绿底黑字
let pass++
}

check_fail(){
echo -e "\033[41;37m [++]FAIL \033[0m"   #失败打印红底白字
let fail++
}

check_manual(){
echo -e "\033[43;30m [++]请手动检测该项或依据实际情况判断!! \033[0m"               #未检测到文件或须手动确认打印黄底黑字
let manual++
}

echo "NO.1-检查是否设置口令生存周期"
pass_max_day=`cat /etc/login.defs | grep PASS_MAX_DAYS | grep -v ^# | awk '{print $2}'`

if [ "$pass_max_day" -lt "90" ]; then
        check_pass
elif [ "$pass_max_day" -gt "90" ]; then
	echo "口令生存周期:$pass_max_day"
        check_fail
else
        check_manual
fi
echo $separator

echo "NO.2-检查是否设置口令最小长度"
pass_min_len=`cat /etc/login.defs | grep PASS_MIN_LEN | grep -v ^# | awk '{print $2}'`
if test -n "$pass_min_len"; then
        if [ "$pass_min_len" -lt "8" ]; then
		echo "口令最小长度:$pass_min_len"
                check_fail
        elif [ "$pass_min_len" -ge "8" ]; then
                check_pass
        else 
                check_manual
        fi
else 
        check_manual
fi
echo $separator

echo "NO.3-检查是否配置口令过期提醒"
pass_warn_age=`cat /etc/login.defs | grep PASS_WARN_AGE | grep -v ^# | awk '{print $2}'`
if test -n "$pass_warn_age"; then
        if [ "$pass_warn_age" -lt 30 ]; then
		echo "口令过期提醒天数:$pass_warn_age"
                check_fail
        elif [ "$pass_warn_age" -ge "30" ]; then
                check_pass
        else
                check_manual
        fi
else
        check_manual
fi 
echo $separator

echo "NO.4-检查是否存在空口令账户"
empty_user=`cat /etc/shadow | awk -F : 'length($2)==0 {print $1}'`
if test -z "$empty_user"; then
        check_pass

elif test -n "$empty_user"; then
        echo "请检查空口令账户:$empty_user"
        check_fail
else
        check_manual
fi
echo $separator

echo "NO.5-检查是否存在特权账户"
root_account=`cat /etc/passwd | awk -F : '($3==0){print $1}'`
if [ $root_account=="root" ]; then
        check_pass

else
	echo "请检查uid为0的账户: $root_account"
        check_fail
fi
echo $separator


echo "NO.6-检查错误登录是否记录到日志"
FailLogin_log=`cat /etc/login.defs | grep FAILLOG_ENAB | grep -v ^# | awk '{print $2}'`
if [ $FailLogin_log=="yes" ]; then
        check_pass
elif [ $FailLogin_log=="no" ]; then
        check_fail
else
        check_manual
fi
echo $separator

echo "NO.7-检查口令复杂度"
min_class=`cat /etc/security/pwquality.conf | grep minclass | grep -v ^# | awk '{print $3}'`
if [ "$min_class" -lt "3" ]; then
	echo "口令类型少于3种!"
	check_fail
elif [ "$min_class" -ge "3" ]; then
	check_pass
else
check_manual
fi
echo $separator

echo "NO.8-检查重要文件的权限"
for i in /etc/shadow /etc/gshadow
do
	tmppe=`stat -c %a ${i}`
	if [ "$tmppe" -gt 400 ]; then
		echo "${i} 权限为$tmppe"
		check_fail
	elif [ "$tmppe" -le 400  ]; then
		echo "${i} 权限为$tmppe"
		check_pass
	else
		check_manual
	fi
done

for i in /etc/passwd /etc/group /etc/services /etc/profile
do
        tmppe=`stat -c %a ${i}`

        if [ "$tmppe" -gt 644 ]; then
                echo "${i} 权限为$tmppe" 
                check_fail
        elif [ "$tmppe" -le 644  ]; then
		echo "${i} 权限为$tmppe"
                check_pass
        else
                check_manual
        fi
done

tmppe=`stat -c %a /tmp`

if [ "$tmppe" -gt 750 ]; then
	echo "/tmp目录的权限为$tmppe"
	check_fail
elif [ "$tmppe" -le 750 ]; then
	check_pass
else
	check_manual
fi
echo $separator

echo "NO.9-检查日志服务状态"
service_status=`systemctl status rsyslog | grep Active | awk '{print $2}'`
if [ $service_status == "inactive" ]; then
	echo "日志rsyslog服务状态为:$service_status"
	check_fail
elif [ $service_status == "active" ]; then
	check_pass
else
	check_manual
fi
echo $separator

echo "NO.10-检查常见日志文件是否非任意用户读写,建议非同组用户不可写"
for f in /var/log/cron /var/log/secure /var/log/httpd /var/log/auth.log /var/log/btmp
do
	if [ -a ${f} ]; then
		log_per=`stat -c %a ${f}`
		if [ "$log_per" -ge 770 ]; then
			echo "${f} 的权限为$log_per"
			check_fail
		else
			echo "${f}的权限为$log_per"
			check_pass
		fi
	else
		echo "${f}文件不存在!"
		check_manual
	fi
done

echo $separator

echo "NO.11-检查FTP是否允许匿名登录"
ps_tmp=`ps -ef | grep ftp | grep -v grep`
if [ -z "$ps_tmp" ]; then
	echo "ftp服务未开启"
	check_pass
else
	an_login=`cat /etc/vsftpd/vsftpd.conf | grep "anonymous_enable=NO" | grep -v ^#`
	if [ -z "$an_login" ]; then
		check_fail
	else
		echo "匿名登录:$an_login"
		check_pass
	fi
fi
echo $separator

echo "NO.12-检查history命令显示的条数,建议设置5条"
echo "历史命令显示条数:`cat /etc/profile | grep "HISTSIZE" | awk -F "=" '{print $2}'`"
check_manual
echo $separator
echo " 共检测项:$((pass+fail+manual))"
echo -e "\033[32m 通过项:$pass \033[0m"
echo -e "\033[31m 失败项:$fail \033[0m"
echo -e "\033[33m 手动检查项:$manual \033[0m"
echo "已完成Linux安全基线检查"
