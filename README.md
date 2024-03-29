# debian-autoinstall

auto install debian for kvm vps with netboot.

#### Sample
```
# use default options: debian10 amd64 user:root password:HelloDebian ssh_port:22
wget -Odi.sh https://github.com/fcying/debian-di/raw/master/di.sh && bash di.sh
```

#### Dependence
```
apt-get update
apt-get install -y wget gawk cpio libpcre3 openssl ca-certificates
```

#### Min Memory Requirement (free -m)
```
debian 10 >= 285M
debian 11 >= 440M
debian 12 >= 440M
```

#### Options
* `--help`
* `-d/--debian [value]`</br>
    10 or strtch</br>
    debian version, default`10`
* `-a/--arch [value]`</br>
    architecture version: `amd64` `i386` `arm64`</br>
    default`amd64`
* `-m/--mirror [value]`</br>
    apt mirror, ex: `-m https://opentuna.cn/debian`</br>
    or `-m china`, use mirror `https://opentuna.cn/debian`
* `--dns [value]`</br>
    default`8.8.8.8`
* `-u/--user [value]`</br>
    user name, default:`root`
* `-p/--password [value]`</br>
    user password, default:`HelloDebian`
* `--port [value]`</br>
    ssh port
* `-b/--biosdevname`</br>
    interface name not use `ethx`
* `--hostname`</br>
    default use `$(hostname)`
* `-6/--ipv6`</br>
    enable ipv6
* `--dhcp [value]`</br>
    1: use DHCP    0: static ip from current system
    default `1`
* `--ip-addr [value]`</br>
    if not set, get current system ip addr
* `--ip-gate [value]`</br>
    if not set, get current system ip gate
* `--ip-mask [value]`</br>
    if not set, get current system ip mask

