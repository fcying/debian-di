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

#### Min Memory Requirement
```
debian 9 >= 192M
debian 10 >= 320M
debian 11 >= 480M
```

#### Options
* `--help`
* `-d/--debian [value]`</br>
    9, 10, 11, ... or bullseye, buster, ...</br>
    debian version, default`10`
* `--ubuntu [value]`</br>
    18.04, 20.04, ... or bullseye, buster, ...
* `-a/--arch [value]`</br>
    architecture version: `amd64` `i386` `arm64`</br>
    default`amd64`
* `-m/--mirror [value]`</br>
    apt mirror, ex: `-m https://opentuna.cn/debian`</br>
    or `-m china`, use mirror `https://opentuna.cn/debian`
* `-u/--user [value]`</br>
    user name, default:`root`
* `-p/--password [value]`</br>
    user password, default:`HelloDebian`
* `--port [value]`</br>
    ssh port
* `-b/--biosdevname`</br>
    interface name use `ethx`
* `-6/--ipv6`</br>
    enable ipv6
* `--dhcp`</br>
    use DHCP
* `--ip-addr [value]`</br>
    if not set, get current system ip addr
* `--ip-gate [value]`</br>
    if not set, get current system ip gate
* `--ip-mask [value]`</br>
    if not set, get current system ip mask

