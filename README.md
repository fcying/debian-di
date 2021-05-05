# debian-autoinstall

auto install debian for kvm vps with netboot.

#### Sample
```
# use default options: debian10 amd64 password:HelloDebian
wget -qOinstall.sh https://github.com/fcying/debian-autoinstall/raw/master/install.sh && bash install.sh

# install debian9 i386 password:123 huaweimirros
bash install.sh -d 9 -v 32 -p 123 -m http://mirrors.huaweicloud.com/debian

# install debian10 with special network
bash install.sh -d 10 --ip-addr x.x.x.x --ip-gate x.x.x.x --ip-mask x.x.x.x

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

#### Options
```
./install.sh --help
Usage:
    bash install.sh:
        -d/--debian [8|9|10|value]
        -u/--ubuntu [18.04|20.04|value]
        -v/--ver [32|64]
        -m/--mirror [value]
        -p/--password [value]
        -b/--biosdevname
        -6/--ipv6
        -i/--interface [value]
        --ip-addr [value]
        --ip-gate [value]
        --ip-mask [value]
```