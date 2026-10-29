#!/bin/bash
function checkIt()
{
 ps auxw | grep -P '\b'$1'(?!-)\b' >/dev/null
 if [ $? != 0 ]
 then
   echo -e $1" ---\033[31m bad \033[39m";
 else
   echo -e $1" ---\033[32m good \033[39m";
 fi;
}

services="
nginx
php-fpm
redis
mariadbd
smbd
vsftpd
firewalld
fail2ban-server
plexmediaserver
transmission
vlmcsd
"
#fail2ban-client status
#fail2ban-client status sshd
netstat -ntlp | grep LISTEN

for service in $services
do
checkIt $service
done