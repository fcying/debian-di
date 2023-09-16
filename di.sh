#!/usr/bin/env bash

## License: GPL
## It can reinstall Debian system with network.
## Default root password: HelloDebian
## Written By fcying

tmpArch=''
tmpDIST='10'
tmpMirror=''
ip_addr=''
ip_mask=''
ip_gate=''
useDHCP=1
Release='debian'
biosdevname='net.ifnames=0 biosdevname=0'
boot_option=' auto=true'
netbootURL=''
linux_mirror=''
user='root'
my_passwd='HelloDebian'
ssh_port='22'
DNS="8.8.8.8"
HOSTNAME=$(hostname)

# debconf-get-selections --installer >> file
# debconf-get-selections >> file
preInstall='openssh-server wget curl vim git debconf-utils locales-all'
isUEFI='false'

BLACK="\e[0;30m"
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
MAGENTA="\e[0;35m"
CYAN="\e[0;36m"
WHITE="\e[0;37m"
NC="\e[0m"  # No Color

function logd()     { echo -e "$@"; }
function logi()     { echo -e "${BLUE}$@${NC}"; }
function logw()     { echo -e "${YELLOW}$@${NC}"; }
function loge()     { echo -e "${RED}$@${NC}"; }

while [[ $# -ge 1 ]]; do
    case $1 in
        -a|--arch)
            shift
            tmpArch="$1"
            shift
            ;;
        -d|--debian)
            shift
            Release='debian'
            tmpDIST="$1"
            shift
            ;;
        --ubuntu)
            shift
            Release='ubuntu'
            tmpDIST="$1"
            shift
            ;;
        -u|--user)
            shift
            user="$1"
            shift
            ;;
        -p|--password)
            shift
            my_passwd="$1"
            shift
            ;;
        --port)
            shift
            ssh_port="$1"
            shift
            ;;
        --dhcp)
            shift
            useDHCP="$1"
            shift
            ;;
        --ip-addr)
            shift
            ip_addr="$1"
            shift
            ;;
        --ip-mask)
            shift
            ip_mask="$1"
            shift
            ;;
        --ip-gate)
            shift
            ip_gate="$1"
            shift
            ;;
        -b|--biosdevname)
            shift
            biosdevname=''
            ;;
        --hostname)
            shift
            HOSTNAME="$1"
            shift
            ;;
        -m|--mirror)
            shift
            tmpMirror="$1"
            shift
            ;;
        --dns)
            shift
            DNS="$1"
            shift
            ;;
        -6|--ipv6)
            shift
            boot_option="$boot_option ipv6.disable=1"
            ;;
        *)
            if [ "$1" != "--help" ]; then
                loge "Invaild option: '$1'"
            fi
            echo -e "Usage:"
            echo -e "    bash $(basename $0):"
            echo -e "        -d/--debian [9|10|11|value]"
            echo -e "        --ubuntu [18.04|20.04|value]"
            echo -e "        -v/--ver [i386|amd64|arm64]"
            echo -e "        -m/--mirror [value]"
            echo -e "        --dns [value]"
            echo -e "        -u/--user [value]"
            echo -e "        -p/--password [value]"
            echo -e "        --port [value]"
            echo -e "        -b/--biosdevname"
            echo -e "        --hostname"
            echo -e "        -6/--ipv6"
            echo -e "        --dhcp"
            echo -e "        --ip-addr [value]"
            echo -e "        --ip-gate [value]"
            echo -e "        --ip-mask [value]"
            exit 1;
            ;;
    esac
done

[ "$EUID" -ne '0' ] && loge "This script must be run as root!" && exit 1

if [ -n "$biosdevname" ]; then
    boot_option="$boot_option $biosdevname"
fi

function CheckDependenceBin(){
    ret=0
    for BIN_DEP in `echo "$1" | sed 's/,/\n/g'`
    do
        if [ -n "$BIN_DEP" ]; then
            type $BIN_DEP > /dev/null 2>&1
            if [ $? == 0 ]; then
                echo -en "[${GREEN}ok${NC}]"
            else
                ret=1;
                echo -en "[${GREEN}Not Install${NC}]"
            fi
            echo -e "\t$BIN_DEP"
        fi
    done
    if [ $ret -ne 0 ]; then
        loge "Please install dependence bin."
        exit 1
    fi
}
function CheckDependenceLib(){
    ret=0
    for LIB_DEP in `echo "$1" | sed 's/,/\n/g'`
    do
        if [ -n "$LIB_DEP" ]; then
            if [ $(ldconfig -p | grep -c $LIB_DEP) -eq 0 ]; then
                ret=1;
                echo -en "[${GREEN}Not Install${NC}]"
            else
                echo -en "[${GREEN}ok${NC}]"
            fi
            echo -e "\t$LIB_DEP"
        fi
    done
    if [ $ret -ne 0 ]; then
        loge "Please install dependence lib."
        exit 1
    fi
}

Release=$(echo "$Release" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')

currentRelease=$(cat /proc/version)
if [ $(echo $currentRelease | grep -ic "debian") -ne 0 ]; then
    currentRelease="debian"
elif [ $(echo $currentRelease | grep -ic "centos") -ne 0 ]; then
    currentRelease="centos"
elif [ $(echo $currentRelease | grep -ic "ubuntu") -ne 0 ]; then
    currentRelease="ubuntu"
else
    currentRelease="other"
fi

logi "# Check Dependence"
CheckDependenceBin wget,awk,grep,sed,cut,cat,cpio,gzip,find,dirname,basename
# for grep -P
if [[ "$currentRelease" == 'debian' ]] || [[ "$currentRelease" == 'ubuntu' ]]; then
    CheckDependenceLib libpcre.so.3
fi

[ -n "$my_passwd" ] && CheckDependenceBin openssl

function SelectMirror(){
    [ $# -ge 3 ] || exit 1
    Release="$1"
    DIST=$(echo "$2" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
    arch=$(echo "$3" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
    NewMirror=$(echo "$4" |sed 's/\ //g')
    [ -n "$Release" ] || exit 1
    [ -n "$DIST" ] || exit 1
    [ -n "$arch" ] || exit 1
    if [ "$Release" == "debian" ]; then
        inUpdate=''
        legacyImages=("images")
        mirrors=("http://deb.debian.org/debian" "http://archive.debian.org/debian" "http://mirrors.huaweicloud.com/debian")
    elif [ "$Release" == "ubuntu" ]; then
        inUpdate='-updates'
        legacyImages=("legacy-images" "images")
        mirrors=("http://archive.ubuntu.com/ubuntu" "http://mirrors.huaweicloud.com/ubuntu")
    fi

    [ ! -z $NewMirror ] && mirrors=($NewMirror "${mirrors[@]}")
    for mirror in ${mirrors[@]}
    do
        for legacyImage in ${legacyImages[@]}
        do
            netbootURL="${mirror}/dists/${DIST}${inUpdate}/main/installer-${arch}/current/${legacyImage}/netboot/${Release}-installer/${arch}"
            wget --no-check-certificate --spider --timeout=3 "$netbootURL/initrd.gz" -o /dev/null
            if [ $? -eq 0 ]; then
                linux_mirror=$mirror
                return
            fi
        done
    done
}

# get architecture version {{{
tmpArch="$(echo "$tmpArch" | sed -r 's/(.*)/\L\1/')"  #lowercase
if  [[ "$tmpArch" == 'i386' ]] || [[ "$tmpArch" == 'amd64' ]] || [[ "$tmpArch" == 'arm64' ]]; then
    arch=$tmpArch;
else
    arch=$(dpkg --print-architecture 2> /dev/null) || {
        case $(uname -m) in
            x86_64)
                arch=amd64
                ;;
            aarch64)
                arch=arm64
                ;;
            i386)
                arch=i386
                ;;
            *)
                loge "No --architecture specified"
        esac
    }
fi

if [[ -z "$tmpDIST" ]]; then
    [ "$Release" == 'debian' ] && tmpDIST='buster'
    [ "$Release" == 'ubuntu' ] && tmpDIST='focal'
fi

# check dist {{{
DIST_NUM="$(echo "$tmpDIST" | sed -r 's/(.*)/\L\1/')"
if [ "$Release" == "debian" ]; then
    if [ "$DIST_NUM" == "10" ]; then
        DIST="buster"
    elif [ "$DIST_NUM" == "8" ]; then
        DIST="jessie"
    elif [ "$DIST_NUM" == "9" ]; then
        DIST="stretch"
    elif [ "$DIST_NUM" == "11" ]; then
        DIST="bullseye"
    fi
elif [ "$Release" == "ubuntu" ]; then
    if [ "$DIST_NUM" == "18.04" ]; then
        DIST="bionic"
    elif [ "$DIST_NUM" == "20.04" ]; then
        DIST="focal"
    fi
fi

if [ "$tmpMirror" == "china" ]; then
    tmpMirror="https://opentuna.cn/debian"
fi
SelectMirror "$Release" "$DIST" "$arch" "$tmpMirror"
mirror_host="$(echo "$linux_mirror" |awk -F'://|/' '{print $2}')"
mirror_dir="$(echo "$linux_mirror" |awk -F''${mirror_host}'' '{print $2}')"

if [[ -z "$linux_mirror" ]]; then
    loge "Invaild mirror!"
    [ "$Release" == 'debian' ] && logi "example: http://deb.debian.org/debian";
    [ "$Release" == 'ubuntu' ] && logi "example: http://archive.ubuntu.com/ubuntu";
    exit 1;
fi

if [ "$Release" == "debian" ]; then
    if [ "$linux_mirror" == "http://deb.debian.org/debian" ]; then
        security_host="security.debian.org"
    else
        security_host=${mirror_host}
    fi
else
    security_host="security.ubuntu.com"
fi

# check UEFI {{{
if [ -d "/boot/efi" ]; then
    isUEFI="true"
fi

# init kernel version {{{
kernel="linux-image-$arch"
if [ "$arch" == amd64 ] || [ "$arch" == arm64 ]; then
    if [ "$isUEFI" == "false" ]; then
        kernel="linux-image-cloud-$arch"
    fi
fi
preInstall="$kernel/$DIST $preInstall"

# check DIST valid {{{
FindDist=0
DistsList=$(wget --no-check-certificate -qO- $linux_mirror/dists | grep -Po '(?<=href=").*?(?=/")')
for CheckDist in $DistsList
do
    if [ "$CheckDist" == "$DIST" ]; then
        FindDist=1
        break
    fi
done
if [ $FindDist -eq 0 ]; then
    loge "The dist version not found, Please check it!"
    exit 1;
fi
logi Install $Release-$DIST-$kernel, mirror: $linux_mirror, current os: $currentRelease

# password {{{
my_passwd="$(openssl passwd -1 $my_passwd)"


# get network {{{
logi "get network info"
if [ -n "$ip_addr" ] && [ -n "$ip_mask" ] && [ -n "$ip_gate" ]; then
    IPv4="$ip_addr"
    MASK="$ip_mask"
    GATE="$ip_gate"
else
    DEFAULTNET="$(ip route | grep -Po '^default via (\d{1,3}\.){1,3}\d{1,3}.*' | head -1 | sed 's/proto.*\|onlink.*//g' | awk '{print $NF}')"
    GATE="$(ip route | grep -Po '(?<=^default via )(\d{1,3}\.){1,3}\d{1,3}' | head -1)"
    if [ -n "$DEFAULTNET" ]; then
        IPSUB="$(ip addr | grep $DEFAULTNET | grep 'global' | grep 'brd' | head -1 | grep -Po '(\d{1,3}\.){1,3}\d{1,3}/\d{1,2}')"
        IPv4="$(echo -n $IPSUB | cut -d'/' -f1)"
        NETSUB="$(echo -n $IPSUB | grep -Po '(?<=/)\d{1,2}')"
        if [ -n "$NETSUB" ]; then
            MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5, 252.0.0.0/6,
                254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,
                255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,
                255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,
                255.255.254.0/23, 255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,
                255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |
                grep -Po '(\d{1,3}\.){1,3}\d{1,3}/'$NETSUB'' | cut -d'/' -f1)"
        fi
    fi
fi

logi hostname:$HOSTNAME, IPv4: $IPv4, DNS: $DNS, NETMASK: $MASK, GATEWAY: $GATE
if [ -z "$GATE" ] || [ -z "$MASK" ] || [ -z "$IPv4" ]; then
    loge "Not configure network."
    exit 1
fi


# check memory {{{
memory=$(free -k | grep Mem | awk '{print $2}')
logi "memory is $memory (free -k)"
if [ "$DIST" == "buster" ]; then
    if [ "$memory" -lt 299684 ]; then
        loge "low memory: $memory, need 299684 at least"
        exit 1
    fi
elif [ "$DIST" == "stretch" ]; then
    if [ "$memory" -lt 170660 ]; then
        loge "low memory: $memory, need 170660 at least"
        exit 1
    fi
elif [ "$DIST" == "bullseye" ]; then
    if [ "$memory" -lt 461476 ]; then
        loge "low memory: $memory, need 461476 at least"
        exit 1
    fi
fi


# download boot file {{{
TEST=${TEST:-"0"}
if [[ "$Release" == "debian" ]] || [[ "$Release" == "ubuntu" ]]; then
    logi "download initrd.gz vmlinuz from $netbootURL"
    if [ "$TEST" == "0" ]; then
        wget --no-check-certificate -qO "/boot/vmlinuz" $netbootURL/linux
        if [ $? -ne 0 ]; then
            loge "Download 'vmlinuz' failed!" && exit 1
        fi

        wget --no-check-certificate -qO "/boot/initrd.img" $netbootURL/initrd.gz
        if [ $? -ne 0 ]; then
            loge "Download 'initrd.img' failed!" && exit 1
        fi
    fi
else
    loge "Invalid version $Release."
    exit 1
fi


# modify grub {{{
logi "set new grub"
if [ -f "/boot/grub/grub.cfg" ]; then
    GRUBVER=0 && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg'
elif [ -f "/boot/grub2/grub.cfg" ]; then
    GRUBVER=0 && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg'
elif [ -f "/boot/grub/grub.conf" ]; then
    GRUBVER=1 && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf'
else
    loge "grub not found."
    exit 1
fi

saved_entry=""
GRUBNEW='/tmp/grub.new'
if [ "$GRUBVER" -eq 0 ]; then
    if [ "$(grep -Pc 'menuentry\ .*?{' $GRUBDIR/$GRUBFILE)" -ne 0 ]; then
        # get menuentry
        cat $GRUBDIR/$GRUBFILE | sed -n ':a;N;$!ba;s/\n/%%%%%/g;$p' | grep -Po 'menuentry\ .*?}%%%%%' | head -1 | sed 's/%%%%%/\n/g' >$GRUBNEW
        if [ ! -f $GRUBNEW ]; then
            loge "$GRUBFILE have not menuentry."
            exit 1
        fi
        sed -i "s/menuentry.*/menuentry 'Install OS [$DIST $arch]' --class debian --class gnu-linux --class gnu --class os {/g" $GRUBNEW
        sed -i "/echo.*Loading/d" $GRUBNEW
        INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE | head -1)"
    else
        # check if use /boot/loader/entries, for centos8
        saved_entry=$(cat $GRUBDIR/grubenv | grep "saved_entry" | awk -F= '{print $2}')
        if [ -f "/boot/loader/entries/${saved_entry}.conf" ]; then
            cat "/boot/loader/entries/${saved_entry}.conf" > $GRUBNEW
        else
            loge "saved_entry ${saved_entry} can't find."
            exit 1
        fi
        sed -i "s/title .*/title Install OS [$DIST $arch]/g" $GRUBNEW
    fi

elif [ "$GRUBVER" -eq 1 ]; then
    # for centos 6
    CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >$GRUBNEW
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >$GRUBNEW
    if [ ! -f $GRUBNEW ]; then
        loge "$GRUBFILE config failed."
        exit 1
    fi
    sed -i "/title.*/c\title\ \'Install OS \[$DIST\ $arch\]\'" $GRUBNEW
    sed -i '/^#/d' $GRUBNEW;
    INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
fi

LinuxKernel="$(grep 'linux.*/\|kernel.*/' $GRUBNEW |awk '{print $1}')"
if [ -z "$LinuxKernel" ]; then
    loge "can't find LinuxKernel."
    exit 1
fi
LinuxIMG="$(grep 'initrd.*/' $GRUBNEW |awk '{print $1}')";
if [ -z "$LinuxIMG" ]; then
    sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" $GRUBNEW
    LinuxIMG='initrd'
fi

if [[ "$Release" == 'debian' ]] || [[ "$Release" == 'ubuntu' ]]; then
    boot_option="$boot_option lowmem/low=true -- quiet"
fi

if [ -n "$(grep 'linux.*/\|kernel.*/' $GRUBNEW | awk '{print $2}' | grep '^/boot/')" ]; then
    inBoot="/boot"
else
    inBoot=""
fi

# add boot_option boot failed on centos8
if [ "$currentRelease" == "centos" ]; then
    boot_option=""
fi

sed -i "s|$LinuxKernel.*/.*|$LinuxKernel\t$inBoot/vmlinuz$boot_option|g" $GRUBNEW
sed -i "s|$LinuxIMG.*/.*|$LinuxIMG\t$inBoot/initrd.img|g" $GRUBNEW

if [ -z "$saved_entry" ]; then
    if [ -f "$GRUBDIR/grubenv" ]; then
        sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv
    fi
    sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE
    sed -i ''${INSERTGRUB}'r '$GRUBNEW'' $GRUBDIR/$GRUBFILE
else
    cat $GRUBNEW > /boot/loader/entries/${saved_entry}.conf
fi

chown root:root $GRUBDIR/$GRUBFILE
chmod 444 $GRUBDIR/$GRUBFILE

# modify grub }}}


# unpack initrd
logi "unpack initrd"
rm -rf /tmp/boot && mkdir /tmp/boot && cd /tmp/boot
preseed_file=/tmp/boot/preseed.cfg
gzip -d < /boot/initrd.img | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1


# preseed.cfg {{{
cat > $preseed_file << EOF
d-i debian-installer/locale string en_US
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale select en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

d-i netcfg/choose_interface select auto
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
d-i netcfg/get_ipaddress string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string $DNS
d-i netcfg/confirm_static boolean true

d-i netcfg/get_hostname string $HOSTNAME
d-i netcfg/get_domain string unassigned-domain
d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string $mirror_host
d-i mirror/http/directory string $mirror_dir
d-i mirror/http/proxy string
apt-mirror-setup	apt-setup/mirror/error	select	Retry

d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string $security_host
d-i apt-setup/local0/source boolean false
EOF

# check user {{{
if [ "$user" == "root" ]; then
    PermitRootLogin=yes
cat >> $preseed_file << EOF
d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $my_passwd
d-i user-setup/allow-password-weak boolean true
EOF
else
    PermitRootLogin=no
cat >> $preseed_file << EOF
d-i passwd/root-login boolean false
d-i passwd/make-user boolean true
d-i passwd/user-fullname string
d-i passwd/username string $user
d-i passwd/user-password-crypted password $my_passwd
EOF
fi

# check biosdevname {{{
if [ -n "$biosdevname" ]; then
    echo "d-i debian-installer/add-kernel-opts string $biosdevname" >> $preseed_file
fi

cat >> $preseed_file << EOF
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true

d-i partman/early_command string \
debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"; \
umount /media; \

d-i partman/mount_style select uuid
d-i partman-auto/init_automatically_partition select Guided - use entire disk
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i debian-installer/allow_unauthenticated boolean true

d-i base-installer/kernel/image string $kernel

tasksel tasksel/first multiselect minimal
d-i pkgsel/include string $preInstall
d-i pkgsel/upgrade select none

d-i pkgsel/update-policy select none

popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i grub-installer/force-efi-extra-removable boolean true

d-i preseed/late_command string \
in-target sed -ri 's/^#?Port.*/Port $ssh_port/g' /etc/ssh/sshd_config; \
in-target sed -ri 's/^#?MaxAuthTries.*/MaxAuthTries 10/g' /etc/ssh/sshd_config; \
in-target sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin $PermitRootLogin/g' /etc/ssh/sshd_config; \
in-target sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config; \
in-target sed -ri 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub; \
in-target update-grub;

d-i finish-install/reboot_in_progress note
EOF


if [ "$Release" == "debian" ]; then
    # only for ubuntu
    sed -i 's/umount\ \/media;\ //g' /tmp/boot/preseed.cfg
    sed -i '/pkgsel\/update-policy/d' /tmp/boot/preseed.cfg
    sed -i '/user-setup\/encrypt-home/d' /tmp/boot/preseed.cfg
fi

if [ "$isUEFI" == "false" ]; then
    sed -i '/force-efi-extra-removable/d' /tmp/boot/preseed.cfg
fi

if [ "$useDHCP" -eq 1 ]; then
    sed -i '/netcfg\/disable_autoconfig/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/dhcp_options/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/get_ipaddress.*/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/get_netmask.*/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/get_gateway.*/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/get_nameservers.*/d' /tmp/boot/preseed.cfg
    sed -i '/netcfg\/confirm_static/d' /tmp/boot/preseed.cfg
fi

if [[ "$Release" == "debian" ]] && [[ -f "/boot/firmware.cpio.gz" ]]; then
    gzip -d < /boot/firmware.cpio.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
fi


logi "create new initrd"
rm -f /boot/initrd.img
find . | cpio -H newc --create | gzip -9 > /boot/initrd.img
rm -rf /tmp/boot


logi "reboot && enter auto install, wait a moment, you can check process with VNC."
sleep 3
reboot
