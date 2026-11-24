#!/bin/bash
# Проверить доступность сайта



site1=https://ralf.ru
site2=https://loymax.ralf.ru
site3=https://loymax.ralf.ru/publicapi/v1/Registration/RegisterAnonym
site4=https://loymax.ralf.ru/publicapi/v1.1/Registration/RegisterAnonym
site5=https://loymax.ralf.ru/publicapi/v1.2/Registration/RegisterAnonym
site6=https://loymax.ralf.ru/publicapi/v1.3/Registration/RegisterAnonym
site7=https://loymax.ralf.ru/publicapi
site8=
#--------------------
code2=200
code3=300
code4=400
code5=500
#-------------------
#RED='\033[0;31m'         #  ${RED}
#GREEN='\033[0;32m'      #  ${GREEN}


#echo -en "\033[37;1;41m ralf.ru \033[0m"
#curl -Is https://ralf.ru | head -n 1

#if curl -Is $site1 | head -n 1
#then 
#echo -en "\033[37;1;41m ralf.ru \033[0m"
#fi
echo "$site1" 
curl -Is $site1 | head -n 1
echo "$site2" 
curl -Is $site2 | head -n 1
echo "$site3" 
curl -Is $site3 | head -n 1
echo "$site4" 
curl -Is $site4 | head -n 1
echo "$site5" 
curl -Is $site5 | head -n 1
echo "$site6" 
curl -Is $site6 | head -n 1
echo "$site7" 
curl -Is $site7 | head -n 1
#curl -Is  | head -1