# debian-autoinstall

auto install debian for kvm vps with netboot.

#### Sample
```
# use default options: debian10 amd64 password:HelloDebian
wget -qOinstall.sh https://github.com/fcying/debian-autoinstall/raw/master/install.sh && bash install.sh

# install debian default version with password:hello123
bash <(wget -qO- https://github.com/fcying/debian-autoinstall/raw/master/install.sh) -p hello123

# install debian9 i386 password:hello123 huaweimirros
bash install.sh -d 9 -v 32 -p hello123 -m http://mirrors.huaweicloud.com/debian

# install debian11 with special network
bash install.sh -d 11 --ip-addr x.x.x.x --ip-gate x.x.x.x --ip-mask x.x.x.x

# install debian 10
bash install.sh -d buster

# install debian stable
bash install.sh -d stable

# install ubuntu 20.04
bash install.sh -u 20.04
bash install.sh -u focal
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
```
./install.sh --help
Usage:
    bash install.sh:
        -d/--debian [9|10|11|value]
        -u/--ubuntu [18.04|20.04|value]
        -v/--ver [32|64]
        -m/--mirror [value]
        -p/--password [value]
        -b/--biosdevname
        -6/--ipv6
        -i/--interface [value]
        --dhcp
        --ip-addr [value]
        --ip-gate [value]
        --ip-mask [value]
```
