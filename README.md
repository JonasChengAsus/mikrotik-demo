# Configuration

Every router is factory pre-configured with the IP address `192.168.88.1/24` on the ether1 port.

```console
MIKROTIK_RT_IP=192.168.88.1
SSH_PUB_KEY=id_rsa.pub
```

## Use Passwordless SSH/RSA to execute commands

Copy the public key to the MikroTik router

```console
scp ${HOME}/.ssh/${SSH_PUB_KEY} admin@${MIKROTIK_RT_IP}:${SSH_PUB_KEY}
```

Import the public key from the command line

```console
ssh admin@${MIKROTIK_RT_IP} "/user ssh-keys import public-key-file=${SSH_PUB_KEY} user=admin"
```

## Harden security in production

The default username is admin with no password. After you log in for the first time, please create a new user with a password in the "full" group, re-login and delete the default admin user. We highly recommend you to follow the general guidelines of the article [Securing your router](https://wiki.mikrotik.com/wiki/Manual:Securing_Your_Router) to protect the device from any unauthorised access.

Change default username admin to different name, custom name helps to protect access to your rotuer, if anybody got direct access to your router.

```console
/user add name=myname password=mypassword group=full
/user remove admin
```

Most of RouterOS administrative tools are configured at

```console
/ip service print
```

Keep only secure ones,

```console
/ip service disable telnet,ftp,www,api,api-ssl
/ip service print
```

and also change the default port, this will immediately stop most of the random SSH bruteforce login attempts:

```console
/ip service set ssh port=2200
/ip service print
```

RouterOS has built-in options for easy management access to network devices. The particular services should be shutdown on production networks.

Disable mac-telnet services,

```console
/tool mac-server set allowed-interface-list=none
/tool mac-server print
```

Disable mac-winbox services,

```console
/tool mac-server mac-winbox set allowed-interface-list=none
/tool mac-server mac-winbox print
```

Disable mac-ping service,

```console
/tool mac-server ping set enabled=no
/tool mac-server ping print
```

Bandwidth server is used to test throughput between two MikroTik routers. Disable it in production enironment.

```console
/tool bandwidth-server set enabled=no
```

# Known Issues

[ssh command exit-code always 0](https://forum.mikrotik.com/viewtopic.php?t=153623)

# Appendix

[Manual:First time startup](https://wiki.mikrotik.com/wiki/Manual:First_time_startup)

[Manual:Reset](https://wiki.mikrotik.com/wiki/Manual:Reset)

[Manual:System/SSH client](https://wiki.mikrotik.com/wiki/Manual:System/SSH_client)

RouterOS provides SSH client that supports SSHv2 logins to SSH servers reachable from the router.

[Use SSH to execute commands (DSA key login)](https://wiki.mikrotik.com/wiki/Use_SSH_to_execute_commands_(DSA_key_login))

[MikroTik Tutorial: RouterOS SSH Public Key Auth using RSA keys](https://jcutrer.com/howto/networking/mikrotik/routeros-ssh-publickeyauth-rsa-keys)

A Step-by-Step guide to configure SSH Public Key Authentication on a MikroTik router using an RSA keys
