#!/bin/bash
set -e

PROGNAME=$(basename $0)

# default configurations
ADMIN_USER=admin
AICS_USER=aics
AICS_USER_PWD=p@ssw0rd
MIKROTIK_RT_IP=192.168.88.1
SSH_PUB_KEY=id_rsa.pub

##########
# MikroTik commands
##########

# execute MikroTik command
f_exe_mikrotik_cmd(){
  user=$1
  cmd=$2
  ssh -oStrictHostKeyChecking=no ${user}@${MIKROTIK_RT_IP} ${cmd}
}

# copy public key to MikroTik
f_copy_public_key(){
  user=$1
  f_section_echo "Copy the public key ${SSH_PUB_KEY} to the MikroTik router ${MIKROTIK_RT_IP}"
  scp -oStrictHostKeyChecking=no ${HOME}/.ssh/${SSH_PUB_KEY} ${user}@${MIKROTIK_RT_IP}:${SSH_PUB_KEY}
}

# add user and import public key to MikroTik
f_add_user_import_public_key(){
  user=$1
  new_user=$2
  new_pwd=$3

  f_section_echo "Add user ${new_user} to the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/user add name=${new_user} password=${new_pwd} group=full"

  f_section_echo "Import the public key to user ${new_user} on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/user ssh-keys import public-key-file=${SSH_PUB_KEY} user=${new_user}"
}

# remove user from MikroTik
f_remove_user(){
  user=$1
  removed_user=$2
  f_section_echo "Remove user ${removed_user} from the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/user remove ${removed_user}"
}

# disable admin tools
f_disable_admin_tools(){
  user=$1

  f_section_echo "Keep only secure administrative tools on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/ip service disable telnet,ftp,www,api,api-ssl,winbox"

  f_section_echo "List administrative tools on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/ip service print"
}

# disable mac-telnet service
f_disable_mac_telnet_service(){
  user=$1

  f_section_echo "Disable mac-telnet service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server set allowed-interface-list=none"

  f_section_echo "List mac-telnet service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server print"
}

# disable mac winbox service
f_disable_mac_winbox_service(){
  user=$1

  f_section_echo "Disable mac-winbox service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server mac-winbox set allowed-interface-list=none"

  f_section_echo "List mac-winbox service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server mac-winbox print"
}

# disable mac ping service
f_disable_mac_ping_service(){
  user=$1

  f_section_echo "Disable mac-ping service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server ping set enabled=no"

  f_section_echo "List mac-ping service on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool mac-server ping print"
}

# disable bandwidth server
f_disable_bandwidth_server(){
  user=$1

  f_section_echo "Disable bandwidth-server on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool bandwidth-server set enabled=no"

  f_section_echo "List bandwidth-server on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${user} "/tool bandwidth-server print"
}

# harden security
f_harden_security(){
  user=$1
  f_disable_admin_tools ${user}
  f_disable_mac_telnet_service ${user}
  f_disable_mac_winbox_service ${user}
  f_disable_mac_ping_service ${user}
  f_disable_bandwidth_server ${user}
}

# provisioning in factory
f_provisioning(){
  f_copy_public_key ${ADMIN_USER}
  f_add_user_import_public_key ${ADMIN_USER} ${AICS_USER} ${AICS_USER_PWD}
  f_remove_user ${AICS_USER} ${ADMIN_USER}
  f_harden_security ${AICS_USER}
}

# reset factory
f_reset_factory(){
  user=$1
  f_section_echo "Reset the  MikroTik router ${MIKROTIK_RT_IP} factory default configuration"
  f_exe_mikrotik_cmd ${user} "/system reset-configuration"
}

##########
# Utility functions
##########
f_section_echo(){
  echo -e "\n" 1>&2
  echo -e "###################################################################################################" 1>&2
  echo -e "# $@" 1>&2
  echo -e "###################################################################################################" 1>&2
  echo -e "\n" 1>&2
}

f_error_exit(){
  err_code=$?
  if [ ! ${err_code} ]; then
    echo -e "${PROGNAME}: Error ${err_code}" 1>&2
    exit 1
  fi
}

f_provisioning
