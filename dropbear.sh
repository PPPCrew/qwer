#!/bin/bash
#2023
clear
clear
SCPdir="/etc/VPS-MX"
SCPfrm="${SCPdir}/herramientas" && [[ ! -d ${SCPfrm} ]] && exit
SCPinst="${SCPdir}/protocolos"&& [[ ! -d ${SCPinst} ]] && exit
declare -A cor=( [0]="\033[1;37m" [1]="\033[1;34m" [2]="\033[1;31m" [3]="\033[1;33m" [4]="\033[1;32m" )
mportas () {
unset portas
portas_var=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN")
while read port; do
var1=$(echo $port | awk '{print $1}') && var2=$(echo $port | awk '{print $9}' | awk -F ":" '{print $2}')
[[ "$(echo -e $portas|grep "$var1 $var2")" ]] || portas+="$var1 $var2\n"
done <<< "$portas_var"
i=1
echo -e "$portas"
}
fun_ip () {
if [[ -e /etc/VPS-MX/MEUIPvps ]]; then
IP="$(cat /etc/VPS-MX/MEUIPvps)"
else
MEU_IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
MEU_IP2=$(wget -qO- ipv4.icanhazip.com)
[[ "$MEU_IP" != "$MEU_IP" ]] && IP="$MEU_IP2" || IP="$MEU_IP"
echo "$MEU_IP" > /etc/VPS-MX/MEUIPvps
fi
}
fun_eth () {
eth=$(ifconfig | grep -v inet6 | grep -v lo | grep -v 127.0.0.1 | grep "encap:Ethernet" | awk '{print $1}')
    [[ $eth != "" ]] && {
    msg -bar
    echo -e "${cor[3]} $(fun_trans "Aplicar Mejoras Para Mejorar Paquetes SSH?")"
    echo -e "${cor[3]} $(fun_trans "Opcion Para Usuarios Avanzados")"
    msg -bar
    read -p " [S/N]: " -e -i n sshsn
           [[ "$sshsn" = @(s|S|y|Y) ]] && {
           echo -e "${cor[1]} $(fun_trans "Correccion de problemas de paquetes en SSH...")"
           echo -e " $(fun_trans "Cual es la tasa RX")"
           echo -ne "[ 1 - 999999999 ]: "; read rx
           [[ "$rx" = "" ]] && rx="999999999"
           echo -e " $(fun_trans "Cual es la tasa TX")"
           echo -ne "[ 1 - 999999999 ]: "; read tx
           [[ "$tx" = "" ]] && tx="999999999"
           apt-get install ethtool -y > /dev/null 2>&1
           ethtool -G $eth rx $rx tx $tx > /dev/null 2>&1
           }
     msg -bar
     }
}

fun_bar () {
comando="$1"
 _=$(
$comando > /dev/null 2>&1
) & > /dev/null
pid=$!
while [[ -d /proc/$pid ]]; do
echo -ne " \033[1;33m["
   for((i=0; i<10; i++)); do
   echo -ne "\033[1;31m##"
   sleep 0.2
   done
echo -ne "\033[1;33m]"
sleep 1s
echo
tput cuu1 && tput dl1
done
echo -e " \033[1;33m[\033[1;31m####################\033[1;33m] - \033[1;32m100%\033[0m"
sleep 1s
}
del_dropbear () {
 msg -bar
 echo -e "\033[1;32m REMOVIENDO SERVICIO DROPBEAR"
 msg -bar
 service dropbear stop >/dev/null 2>&1
    fun_bar "apt-get remove dropbear -y"
    killall dropbear >/dev/null 2>&1
    rm -rf /etc/dropbear/* >/dev/null 2>&1
    msg -bar
    echo -e "\033[1;32m             DROPBEAR DESINSTALADO EXITO"
    msg -bar
    rm /etc/VPS-MX/.pdropbear.txt &>/dev/null
    [[ -e /etc/default/dropbear ]] && rm /etc/default/dropbear
 return 0
 }
 
 inst_dropbear(){
msg -bar
msg -tit
echo -e "\033[1;32m $(fun_trans "   INSTALADOR DROPBEAR")"
msg -bar
echo -e "\033[1;97m Puede activar varios puertos en orden secuencial\n Ejemplo: \033[1;32m 442 443 444\033[1;37m"
    msg -bar
echo -ne "\033[1;97m Digite  Puertos:\033[1;32m" && read -p " " -e -i "444 445" DPORT
    tput cuu1 && tput dl1
    TTOTAL2=($DPORT)
    for ((i = 0; i < ${#TTOTAL2[@]}; i++)); do
      [[ $(mportas | grep "${TTOTAL2[$i]}") = "" ]] && {
        echo -e "\033[1;33m Puerto Elegido:\033[1;32m ${TTOTAL2[$i]} OK"
        PORT2="$PORT2 ${TTOTAL2[$i]}"
      } || {
        echo -e "\033[1;33m Puerto Elegido:\033[1;31m ${TTOTAL2[$i]} FAIL"
      }
    done
    [[ -z $PORT2 ]] && {
      echo -e "\033[1;31m Ningun Puerto Valido Fue Elegido\033[0m"
      return 1
    }

    msg -bar
    echo -e "\033[1;97m Revisando Actualizaciones"
    fun_bar "apt update; apt upgrade -y > /dev/null 2>&1"
    echo -e "\033[1;97m Instalando Dropbear"
    [[ ! $(cat /etc/shells | grep "/bin/false") ]] && echo -e "/bin/false" >>/etc/shells
    
    local="/etc/dropbear/banner"
  
    fun_bar "apt-get install dropbear -y > /dev/null 2>&1"
    apt-get install dropbear -y >/dev/null 2>&1
    touch $local
    msg -bar
    
    cat <<EOF >/etc/default/dropbear
NO_START=0
DROPBEAR_EXTRA_ARGS="VAR"
DROPBEAR_BANNER="$local"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

    for dpts in $(echo $PORT2); do
      sed -i "s/VAR/-p $dpts VAR/g" /etc/default/dropbear
    done
    sed -i "s/VAR//g" /etc/default/dropbear
    
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
    dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key >/dev/null 2>&1
    service ssh restart >/dev/null 2>&1
 #
    service dropbear restart
   #
    for ufww in `echo $PORT2`; do
    ufw allow $ufww/tcp > /dev/null 2>&1
  done
    sleep 3s
    echo "$PORT2" >/etc/VPS-MX/.pdropbear.txt
    echo -e "\033[1;92m        >> DROPBEAR INSTALADO CON EXITO <<"
    msg -bar
    #
}
pid_inst(){
  proto="dropbear"
  portas=$(lsof -V -i -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND")
  for list in $proto; do
    case $list in
      dropbear)
      portas2=$(echo $portas|grep -w "LISTEN"|grep -w "$list")
      [[ $(echo "${portas2}"|grep "$list") ]] && inst[$list]="\033[1;32m[ACTIVO] " || inst[$list]="\033[1;31m[DESACTIVADO]";;
    esac
  done
}
	clear
	pid_inst
	msg -tit
	echo ""
	echo -e "	\e[1;97mSERVICIO: ${inst[dropbear]}"
	msg -bar
	if [[ -e /etc/default/dropbear ]]; then
	echo -e "  $(msg -verd "[1]")$(msg -verm2 "➛ ")$(msg -azu "DESINSTALAR SERVICIO DROPBEAR  ")"
	else
	echo -e "  $(msg -verd "[1]")$(msg -verm2 "➛ ")$(msg -azu "INSTALAR SERVICIO DROPBEAR  ")"
	fi
	echo -e "  $(msg -verd "[0]")$(msg -verm2 "➛ ")$(msg -azu "VOLVER")"
	msg -bar
	echo -ne "  \033[1;37mSelecione Una Opcion : "
read opc
case $opc in
1)
clear
if [[ -e /etc/default/dropbear ]]; then
del_dropbear
else
inst_dropbear
fi
;;
0)exit;;
esac