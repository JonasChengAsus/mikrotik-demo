#!/bin/bash
set -e

PROGNAME=$(basename $0)

# default configurations
DRYRUN=0 # 1 to skip MikroTik commands
ADMIN_USER=admin
AICS_USER=admin
AICS_USER_PWD=p@ssw0rd
AICS_BRIDGE=aics-net
AICS_IP_POOL=aics-dhcp
MIKROTIK_RT_IP=192.168.88.1
SSH_PUB_KEY=id_rsa.pub

##########
# MikroTik commands
##########

# execute MikroTik command
f_exe_mikrotik_cmd(){
  if [ ${DRYRUN} -eq 0 ]; then
    user=$1
    cmd=$2
    ssh -oStrictHostKeyChecking=no ${ADMIN_USER}@${MIKROTIK_RT_IP} ${cmd}
  fi
}

# copy public key to MikroTik
f_copy_public_key(){
  user=$1

  f_section_echo "Copy the public key ${SSH_PUB_KEY} to the MikroTik router ${MIKROTIK_RT_IP}"

  if [ -f ${HOME}/.ssh/${SSH_PUB_KEY} ]; then
    if [ ${DRYRUN} -eq 0 ]; then
      scp -oStrictHostKeyChecking=no ${HOME}/.ssh/${SSH_PUB_KEY} ${user}@${MIKROTIK_RT_IP}:${SSH_PUB_KEY}
    fi
  else
    echo -e "Public key ${HOME}/.ssh/${SSH_PUB_KEY} does not exist"
    exit 2
  fi
}

# reset admin password
f_reset_admin_pwd(){
  new_pwd=$1

  f_section_echo "Reset user ${ADMIN_USER} password on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/user set 0 password=${new_pwd}"
}

# add user and import public key to MikroTik
f_reset_pwd_import_public_key(){
  new_pwd=$1

  # f_section_echo "Add user ${new_user} to the MikroTik router ${MIKROTIK_RT_IP}"
  # f_exe_mikrotik_cmd ${user} "/user add name=${new_user} password=${new_pwd} group=full"

  f_reset_admin_pwd ${new_pwd}

  f_section_echo "Import the public key to user ${ADMIN_USER} on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/user ssh-keys import public-key-file=${SSH_PUB_KEY} user=${ADMIN_USER}"
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

# rename ether1
f_rename_ether1(){
  f_section_echo "Rename ether1 as internet on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/interface ethernet set [find name=ether1] name=internet"
}

# preset network
f_preset_network(){
  new_router_ip=$1

  # parse IP
  IFS='.' read -ra IPS <<< "${new_router_ip}"
  prefix_ip=${IPS[0]}.${IPS[1]}.${IPS[2]}

  # range of ip pool
  AICS_DHCP_RANGE_FROM=${prefix_ip}.2
  AICS_DHCP_RANGE_TO=${prefix_ip}.254

  # gateway IP and CIDR
  AICS_GATEWAY_IP=${new_router_ip}
  AICS_GATEWAY_CIDR=${prefix_ip}.0/24

  f_rename_ether1

  # 1. create IP pool
  f_section_echo "Create IP pool ${AICS_IP_POOL} (${AICS_DHCP_RANGE_FROM}-${AICS_DHCP_RANGE_TO}) on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip pool add name=${AICS_IP_POOL} ranges=${AICS_DHCP_RANGE_FROM}-${AICS_DHCP_RANGE_TO}"

  # 2. associate bridge to IP pool
  f_section_echo "Associate bridge ${AICS_BRIDGE} to IP pool ${AICS_IP_POOL} on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip dhcp-server set [find interface=bridge] address-pool=${AICS_IP_POOL} name=aicsconf "

  # 3. create DHCP server network
  f_section_echo "Create DHCP server network address ${AICS_GATEWAY_CIDR} and gateway ${AICS_GATEWAY_IP} on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip dhcp-server network add address=${AICS_GATEWAY_CIDR} gateway=${AICS_GATEWAY_IP} comment=aicsconf"

  # 4. create IP address
  f_section_echo "Createe IP address 192.168.60.1/24 on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip address set [find interface=bridge] address=192.168.60.1/24 network=192.168.60.0 comment=aicsconf"
}

# IP-MAC binding
f_ip_mac_binding(){
  ip_address=$1   # 192.168.60.2
  mac_address=$2  # c4:41:1e:74:5d:89

  f_section_echo "Bind MAC ${mac_address} to IP ${ip_address} on the MikroTik router ${MIKROTIK_RT_IP}"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip dhcp-server lease remove [find mac-address=${mac_address}]"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/ip dhcp-server lease add address=${ip_address} mac-address=${mac_address}"
}

# provisioning in factory
f_provisioning(){
  f_copy_public_key ${ADMIN_USER}
  f_reset_pwd_import_public_key ${AICS_USER_PWD}
  f_harden_security ${ADMIN_USER}
}

# reset factory default configuration
f_reset_factory(){
  f_section_echo "Reset the  MikroTik router ${MIKROTIK_RT_IP} factory default configuration"
  f_exe_mikrotik_cmd ${ADMIN_USER} "/system reset-configuration"
}

##########
# Utility functions
##########
f_section_echo(){
  echo -e "" 1>&2
  echo -e "###################################################################################################" 1>&2
  echo -e "# $@" 1>&2
  echo -e "###################################################################################################" 1>&2
  echo -e "" 1>&2
}

f_exit_on_error(){
  code=$?
  if [ ${code} -ne 0 ]; then
    echo -e "${PROGNAME}: Error ${err_code}" 1>&2
    exit 1
  fi
}

usage(){
  echo -e "Usage: ${PROGNAME}
                  [ --network new_router_ip ]
                  [ --resetpwd new_password ]
                  [ --bind ip mac_address ]
                  [ --provisioning ]
                  [ --resetall ]
                  [ --password password ]" 1>&2
  echo -e "" 1>&2
  echo -e "  === Main Operations ==="
  echo -e "  Preset router network: ${PROGNAME} --network new_router_ip" 1>&2
  echo -e "  Reset admin password and import current user SSH public key: ${PROGNAME} --resetpwd new_password" 1>&2
  echo -e "  Bind IP and MAC address: ${PROGNAME} --bind ip mac_address" 1>&2
  echo -e "  Provisioning AICS configuration: ${PROGNAME} --provisioning" 1>&2
  echo -e "  Reset factor default configuration: ${PROGNAME} --resetall" 1>&2
  echo -e "  === Support Arguments ===" 1>&2
  echo -e "  Specify IP of the target router with [--routerip router_ip], default ${MIKROTIK_RT_IP}" 1>&2
  echo -e "  Skip performing MikroTik commands with [--dry-run]" 1>&2
  echo -e "" 1>&2
  exit 2
}

# require to install getopt on macOS
platform=`uname`
if [ "${platform}" == "Darwin" ] && [ ! -f "/opt/local/bin/port" ]; then
  echo -e "Please install MacPorts and GNU getopt on macOS" 1>&2
  echo -e "> sudo port install getopt" 1>&2
  exit 1
fi

PARSED_ARGUMENTS=$(getopt -a -n ${PROGNAME} -l network:,resetpwd:,bind:,provisioning,resetall,password:,routerip:,dry-run -- "$@")
if [ $? -ne 0 ]; then usage; fi

OPERATION=""
while [ $# -gt 0 ]; do
  case "$1" in
    # main operation
    --network)
      OPERATION=$1
      f_section_echo "Operation '${OPERATION}'"
      new_router_ip="$2"
      echo -e "set new router ip ${new_router_ip}" 1>&2
      shift
      ;;
    --resetpwd)
      OPERATION=$1
      f_section_echo "Operation '${OPERATION}'"
      new_password="$2"
      echo -e "set new password ${new_password}" 1>&2
      shift
      ;;
    --bind)
      OPERATION=$1
      f_section_echo "Operation '${OPERATION}'"
      ip="$2"
      mac_address="$3"
      echo -e "set IP ${ip} and MAC address ${mac_address}" 1>&2
      shift; shift;
      ;;
    --provisioning)
      OPERATION=$1
      f_section_echo "Operation '${OPERATION}'"
      ;;
    --resetall)
      OPERATION=$1
      f_section_echo "Operation '${OPERATION}'"
      ;;
    # support arguments
    --password)
      AICS_USER_PWD="$2"
      echo -e "set admin password" 1>&2
      shift
      ;;
    --routerip)
      MIKROTIK_RT_IP="$2"
      echo -e "set target router ip ${MIKROTIK_RT_IP}" 1>&2
      shift
      ;;
    --dry-run)
      DRYRUN=1
      echo -e "set dry-run ${DRYRUN}" 1>&2
      ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --)
      break
      ;;
    # If invalid options were passed, then getopt should have reported an error
    *)
      echo -e "Unexpected option: '$1'." 1>&2
      usage
      ;;
  esac
  shift
done

# Perform operation
if [ "${OPERATION}" == "" ]; then
  echo -e "Missing operation which is required." 1>&2
  usage;
fi

if [ "${OPERATION}" == "--network" ]; then
  f_section_echo "Preset router network configuration"
  f_preset_network ${new_router_ip}
elif [ "${OPERATION}" == "--resetpwd" ]; then
  f_section_echo "Reset admin password and import ${USER}'s SSH public key"
  f_reset_admin_pwd ${new_password}
elif [ "${OPERATION}" == "--bind" ]; then
  f_section_echo "Bind IP and MAC address"
  f_ip_mac_binding ${ip} ${mac_address}
elif [ "${OPERATION}" == "--provisioning" ]; then
  f_section_echo "Provisioning AICS configuration"
  f_provisioning
elif [ "${OPERATION}" == "--resetall" ]; then
  f_section_echo "Reset factory default configuration"
  f_reset_factory
else
  echo -e "Unexpected operation: '${OPERATION}'." 1>&2
  usage
fi
