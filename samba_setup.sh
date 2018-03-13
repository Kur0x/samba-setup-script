#!/bin/sh
share_path="/home/SMB"
password=""
# Check if user is root
rootness(){
	if [[ $EUID -ne 0 ]]; then
	   echo "Error:This script must be run as root!" 1>&2
	   exit 1
	fi
}

rand(){
	index=0
	str=""
	for i in {a..z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
	for i in {A..Z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
	for i in {0..9}; do arr[index]=${i}; index=`expr ${index} + 1`; done
	for i in {1..10}; do str="$str${arr[$RANDOM%$index]}"; done
	echo ${str}
}

get_char(){
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
}

preinstall_samba(){
	# echo "Please enter share foler home:"
	# read -p "(Default home: /home/SMB):" share_path
	# [ -z ${share_path} ] && share_path="/home/SMB"

	password=`rand`
	echo "Please enter smbroot's password:"
	read -p "(Default Password: ${password}):" tmppassword
	[ ! -z ${tmppassword} ] && password=${tmppassword}

	echo
	echo "Samba root account:smbroot"
	echo "password:${password}"
	echo
	echo "Press any key to start... or press Ctrl + C to cancel."
	char=`get_char`
}

install_samba(){
	setenforce 0
	sed -i 's/enforcing/disabled/g' /etc/selinux/config
	rmdir ${share_path} 1>/dev/null 2>&1
	if [ -d ${share_path} ]; then
		echo "This directory already exist: ${share_path}"
		echo "exit"
		exit 1
	fi
	echo "Installing samba..."
	yum install -y samba
	config_samba
}

config_samba(){
	groupadd sambagp
	useradd smbroot -g sambagp -s /sbin/nologin -M # samba manager

	mkdir -p ${share_path}
	chown smbroot:sambagp ${share_path}
	echo -e "${password}\n${password}" | smbpasswd -a smbroot 1>/dev/null 2>&1

	echo "Changing Samba configuration..."

	cp /etc/samba/smb.conf /etc/samba/smb.conf.bak  # backup samba conf

	cat > /etc/samba/smb.conf <<EOF
#================== Global Settings =====================
[global]
	dos charset = cp936
	; unix charset = GBK
# ----------------------- Network Related Options -------------------------
	workgroup = WORKGROUP
	server string = Samba Server Version %v
	netbios name = SmbServer
	;interfaces = lo eth0 192.168.88.35/24
	;hosts allow = 192.168.80.
	wins support = yes
	dns proxy = yes
	name resolve order = wins host lmhosts bcas
	;bind interfaces only = yes
# --------------------------- Logging Options -----------------------------
	log file = /var/log/samba/log.%m
	log level = 2
	max log size = 500
# ----------------------- Standalone Server Options ------------------------
	security = user
	passdb backend = tdbsam
# --------------------------- Printing Options -----------------------------
	load printers = no
	cups options = raw
#============================ Share Definitions ==============================
# [share]
# 	comment = Share
# 	path = ${share_path}
# 	public = no
# 	available = yes
# 	admin users = smbroot
# 	valid users = @sambagp
# 	writable = yes
# 	write list = @sambagp
# 	create mask= 0755
# 	directory mask= 0755
# 	browseable = yes
EOF
}

finally(){
	systemctl enable smb.service
	systemctl start smb.service
	systemctl enable nmb.service
	systemctl start nmb.service

	echo
	echo "###############################################################"
	echo "# Samba Server Installer                                      #"
	echo "# System Supported: CentOS 7+ / Redhat 7+                     #"
	echo "# Intro: A samba server auto install and setup script         #"
	echo "# Author: KuroX <x@kuro-x.com>                                #"
	echo "###############################################################"
	echo "Install complete!"
	echo "Enjoy it!!(^з^)-☆"
	echo
	echo "sambaroot : smbroot"
	echo "Password : ${password}"
	echo
	echo "If you want to modify user settings, please use below command(s):"
	echo "samba_setup -a (Add a user)"
	echo "samba_setup -d (Delete a user)"
	echo "samba_setup -l (List all users)"
	echo "samba_setup -m (Modify a user password)"
	echo
	echo
}

smb(){
	clear
	echo
	echo "###############################################################"
	echo "# Samba Server Installer                                      #"
	echo "# System Supported: CentOS 7+ / Redhat 7+                     #"
	echo "# Intro: A samba server auto install and setup script         #"
	echo "# Author: KuroX <x@kuro-x.com>                                #"
	echo "###############################################################"
	echo
	rootness
	preinstall_samba
	install_samba
	finally
}

add_conf(){
	user=$1
	grep -w "\[${user}\]" /etc/samba/smb.conf 1>/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "config already exist!"
		exit 1
	fi
	cat >> /etc/samba/smb.conf <<EOF
[${user}]
	comment = ${user}
	path = ${share_path}/${user}
	public = no
	available = yes
	admin users = smbroot
	writable = yes
	read list = 
	write list = smbroot ${user}
	valid users = smbroot ${user}
	create mask= 0755
	directory mask= 0755
	browseable = yes
#end[${user}]
EOF
}
add_folder(){
	folder=$1
	ls ${share_path} | grep -w "\[${folder}\]"  1>/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "folder already exist!"
		exit 1
	fi
	mkdir -p ${share_path}/${folder}
	#chown ${user}:sambagp ${share_path}/${user}
	cat >> /etc/samba/smb.conf <<EOF
[${folder}]
	comment = ${folder}
	path = ${share_path}/${folder}
	public = no
	available = yes
	admin users = smbroot
	writable = yes
	read list = 
	write list = smbroot 
	valid users = smbroot 
	create mask= 0755
	directory mask= 0755
	browseable = yes
#end[${folder}]
EOF
	echo "make folder completed."
}

del_folder(){
	folder=$1
	rmdir ${share_path}/${folder}
	sed -i "/\[${folder}\]/,/#end\[${folder}\]/"d /etc/samba/smb.conf
	systemctl reload smb
	echo "Folder (${folder}) del completed."
}

add_p(){
	user=$1
	folder=$2
	rw=$3
	if [ "${rw}" != "read" ] && [ "${rw}" != "write" ]; then
		echo "privilage (${rw}) error"
		exit 1
	fi
	pdbedit -L | grep -w "${user}" > /dev/null 2>&1
	#if not found
	if [ ! $? -eq 0 ];then
		echo "Username (${user}) do not exists. Please re-enter username."
		exit 1
	fi
	cat /etc/samba/smb.conf | grep -w "\[${folder}\]" > /dev/null 2>&1
	if [ ! $? -eq 0 ];then
		echo "folder (${folder}) do not exists. Please re-enter name."
		exit 1
	fi
	# get user from write|read list
	sed -n "/\[${folder}\]/,/#end\[${folder}\]/"p /etc/samba/smb.conf | grep -w "${rw} list.*${user}" > /dev/null 2>&1
	# not found
	if [ ! $? -eq 0 ];then
		# add user to write|read list
		sed -i "/\[${folder}\]/,/#end\[${folder}\]/s/${rw} list.*/& ${user}/g" /etc/samba/smb.conf
	fi
	# get user from valid user
	sed -n  "/\[${folder}\]/,/\#end\[${folder}\]/"p /etc/samba/smb.conf | grep -w  "valid.*${user}"  > /dev/null 2>&1
	# not found
	if [ ! $? -eq 0 ];then
		# add user to valid user
		sed -i "/\[${folder}\]/,/#end\[${folder}\]/s/\tvalid.*/& ${user}/g" /etc/samba/smb.conf
	fi
	echo "Change privilage completed."
}

del_p(){
	user=$1
	folder=$2
	rw=$3
	if [ "${rw}" != "read" ] && [ "${rw}" != "write" ]; then
		echo "privilage (${rw}) error"
		exit 1
	fi
	pdbedit -L | grep -w "${user}" > /dev/null 2>&1
	if [ ! $? -eq 0 ];then
		echo "Username (${user}) do not exists. Please re-enter username."
		exit 1
	fi
	cat /etc/samba/smb.conf | grep -w "\[${folder}\]" > /dev/null 2>&1
	if [ ! $? -eq 0 ];then
		echo "folder (${folder}) do not exists. Please re-enter name."
		exit 1
	fi
	# delete user from write|read list
	sed -i "/\[${folder}\]/,/#end\[${folder}\]/s/\(\t${rw} list.*\) ${user}\(.*\)/\1\2/g" /etc/samba/smb.conf
	# get user in write or read list
	sed -n  "/\[${folder}\]/,/\#end\[${folder}\]/"p /etc/samba/smb.conf | grep -w  "list.*${user}"  > /dev/null 2>&1
	# not in any list
	if [ ! $? -eq 0 ];then
		# delete user from valid user
		sed -i "/\[${folder}\]/,/#end\[${folder}\]/s/\(\tvalid.*\) ${user}\(.*\)/\1\2/g" /etc/samba/smb.conf
	fi
	echo "Change privilage completed."
}

add_user(){
	rootness
	user=$1
	pass=$2
	if [ -z "${user}" ] || [ -z "${pass}" ]; then
		while :
		do
			read -p "Please input Username:" user
			if [ -z ${user} ]; then
				echo "Username can not be empty"
			else
				pdbedit -L | grep -w "${user}" > /dev/null 2>&1
				if [ $? -eq 0 ];then
					echo "Username (${user}) already exists. Please re-enter username."
				else
					break
				fi
			fi
		done
		pass=`rand`
		echo "Please input ${user}'s password:"
		read -p "(Default Password: ${pass}):" tmppass
		[ ! -z ${tmppass} ] && pass=${tmppass}
	fi
	pdbedit -L | grep -w "${user}" > /dev/null 2>&1
	if [ $? -eq 0 ];then
		echo "Username (${user}) already exists. Please re-enter username."
		exit 1
	fi
	useradd ${user} -g sambagp -s /sbin/nologin -M
	echo -e "${pass}\n${pass}" | smbpasswd -a ${user} 1>/dev/null 2>&1

	mkdir -p ${share_path}/${user}
	chown ${user}:sambagp ${share_path}/${user}

	add_conf ${user}
	systemctl reload smb
	echo "Username (${user}) add completed."
}

list_users(){
	pdbedit -L
}

del_user(){
	rootness
	user=$1
	if [ -z "${user}" ]; then
		while :
		do
			read -p "Please input Username:" user
			if [ -z ${user} ]; then
				echo "Username can not be empty"
			else
				break
			fi
		done
	fi
	rmdir ${share_path}/${user}
	sed -i "/\[${user}\]/,/#end\[${user}\]/"d /etc/samba/smb.conf
	smbpasswd -x ${user}
	userdel ${user}
	systemctl reload smb
	echo "Username (${user}) del completed."
}

mod_user(){
	rootness
	user=$1
	pass=$2
	if [ -z "${user}" ] || [ -z "${pass}" ]; then
		while :
		do
			read -p "Please input Username:" user
			if [ -z ${user} ]; then
				echo "Username can not be empty"
			else
				pdbedit -L | grep -w "${user}" > /dev/null 2>&1
				if [ $? -eq 0 ];then
					break
				else
					echo "Username (${user}) do not exists. Please re-enter username."
				fi
			fi
		done
		pass=`rand`
		echo "Please input ${user}'s password:"
		read -p "(Default Password: ${pass}):" tmppass
		[ ! -z ${tmppass} ] && pass=${tmppass}
	fi
	pdbedit -L | grep -w "${user}" > /dev/null 2>&1
	if [ ! $? -eq 0 ];then
		echo "Username (${user}) do not exists. Please re-enter username."
		exit 1
	fi
	# useradd ${user} -g sambagp -s /sbin/nologin -M
	echo -e "${pass}\n${pass}" | smbpasswd -a ${user} 1>/dev/null 2>&1
	systemctl reload smb
	echo "Username (${user}) mod completed."
}

# Main process
action=$1
if [ -z ${action} ] && [ "`basename $0`" != "samba_setup" ]; then
	action=install
fi

case ${action} in
	install)
		smb
		;;
	-l|--list)
		list_users
		;;
	-a|--add)
		add_user $2 $3
		;;
	-d|--del)
		del_user $2
		;;
	-m|--mod)
		mod_user $2 $3
		;;
	-p|--privilage)
		add_p $2 $3 $4
		;;
	-u|--unprivilage)
		del_p $2 $3 $4
		;;
	-f|--folder)
		add_folder $2
		;;
	-g|--delfolder)
		del_folder $2
		;;
	-h|--help)
		echo "Usage: `basename $0` -l,--list                List all users"
		echo "       `basename $0` -a,--add <user> <pass>   Add a user"
		echo "       `basename $0` -d,--del <user>          Delete a user"
		echo "       `basename $0` -m,--mod <user> <pass>   Modify a user password"
		echo "       `basename $0` -p,--privilage <user> <foler> {read|write}   Add a user privilage"
		echo "       `basename $0` -u,--unprivilage <user> <foler> {read|write}   Remove a user privilage"
		echo "       `basename $0` -f,--folder <foler>   create a folder"
		echo "       `basename $0` -g,--delfolder <foler>   deleta a folder"
		echo "       `basename $0` -h,--help                Print this help information"
		;;
	*)
		echo "Usage: `basename $0` [-l,--list|-a,--add|-d,--del|-m,--mod|-p,--privilage|-u,--unprivilage|-f,--folder|-g,--delfolder|-h,--help]" && exit
		;;
esac
