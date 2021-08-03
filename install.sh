#!/bin/bash

## License: GPL
## It can reinstall Debian system with network.
## Default root password: HelloDebian
## Written By fcying


tmpVER=''
tmpDIST='10'
tmpMirror=''
ipAddr=''
ipMask=''
ipGate=''
useDHCP=0
Release='debian'
setIPv6='0'
setInterfaceName='0'
interface='auto'
myPASSWORD=''
netbootURL=''
preInstall='openssh-server wget curl vim git debconf-utils locales-all'
bpoKernel='true'
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


while [[ $# -ge 1 ]]; do
    case $1 in
        -v|--ver)
            shift
            tmpVER="$1"
            shift
            ;;
        -d|--debian)
            shift
            Release='debian'
            tmpDIST="$1"
            shift
            ;;
        -u|--ubuntu)
            shift
            Release='ubuntu'
            tmpDIST="$1"
            shift
            ;;
        -p|--password)
            shift
            myPASSWORD="$1"
            shift
            ;;
        -i|--interface)
            shift
            interface="$1"
            shift
            ;;
        --dhcp)
            useDHCP=1
            shift
            ;;
        --ip-addr)
            shift
            ipAddr="$1"
            shift
            ;;
        --ip-mask)
            shift
            ipMask="$1"
            shift
            ;;
        --ip-gate)
            shift
            ipGate="$1"
            shift
            ;;
        -b|--biosdevname)
            shift
            setInterfaceName='1'
            ;;
        -m|--mirror)
            shift
            tmpMirror="$1"
            shift
            ;;
        -6|--ipv6)
            shift
            setIPv6='1'
            ;;
        *)
            if [ "$1" != "--help" ]; then
                echo -e "Invaild option: '$1'"
            fi
            echo -e "Usage:"
            echo -e "    bash $(basename $0):"
            echo -e "        -d/--debian [9|10|11|value]"
            echo -e "        -u/--ubuntu [18.04|20.04|value]"
            echo -e "        -v/--ver [i386|amd64|arm64]"
            echo -e "        -m/--mirror [value]"
            echo -e "        -p/--password [value]"
            echo -e "        -b/--biosdevname"
            echo -e "        -6/--ipv6"
            echo -e "        -i/--interface [value]"
            echo -e "        --dhcp"
            echo -e "        --ip-addr [value]"
            echo -e "        --ip-gate [value]"
            echo -e "        --ip-mask [value]"
            exit 1;
            ;;
    esac
done

[ "$EUID" -ne '0' ] && echo -e "${RED}Error${NC}: This script must be run as root!" && exit 1

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
        echo -e "${RED}Error${NC}: Please install dependence bin."
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
        echo -e "${RED}Error${NC}: Please install dependence lib."
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

echo -e "${CYAN}# Check Dependence${NC}"
if [[ "$Release" == 'debian' ]] || [[ "$Release" == 'ubuntu' ]]; then
    CheckDependenceBin wget,awk,grep,sed,cut,cat,cpio,gzip,find,dirname,basename

    # for grep -P
    if [ "$currentRelease" == "debian" ]; then
        CheckDependenceLib libpcre.so.3
    fi
fi

[ -n "$myPASSWORD" ] && CheckDependenceBin openssl

function SelectMirror(){
    [ $# -ge 3 ] || exit 1
    Release="$1"
    DIST=$(echo "$2" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
    VER=$(echo "$3" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
    NewMirror=$(echo "$4" |sed 's/\ //g')
    [ -n "$Release" ] || exit 1
    [ -n "$DIST" ] || exit 1
    [ -n "$VER" ] || exit 1
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
            netbootURL="${mirror}/dists/${DIST}${inUpdate}/main/installer-${VER}/current/${legacyImage}/netboot/${Release}-installer/${VER}"
            wget --no-check-certificate --spider --timeout=3 "$netbootURL/initrd.gz" -o /dev/null
            if [ $? -eq 0 ]; then
                echo $mirror---$netbootURL
                return
            fi
        done
    done
}

# get architecture version {{{
tmpVER="$(echo "$tmpVER" | sed -r 's/(.*)/\L\1/')"  #lowercase
if  [[ "$tmpVER" == 'i386' ]] || [[ "$tmpVER" == 'amd64' ]] || [[ "$tmpVER" == 'arm64' ]]; then
    VER=$tmpVER;
else
    VER=$(dpkg --print-architecture 2> /dev/null) || {
        case $(uname -m) in
            x86_64)
                VER=amd64
                ;;
            aarch64)
                VER=arm64
                ;;
            i386)
                VER=i386
                ;;
            *)
                echo "No --architecture specified"
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
LinuxMirror=$(SelectMirror "$Release" "$DIST" "$VER" "$tmpMirror")
netbootURL=$(echo "$LinuxMirror" |awk -F'---' '{print $2}')
LinuxMirror="$(echo "$LinuxMirror" |awk -F'---' '{print $1}')"
MirrorHost="$(echo "$LinuxMirror" |awk -F'://|/' '{print $2}')"
MirrorFolder="$(echo "$LinuxMirror" |awk -F''${MirrorHost}'' '{print $2}')"

if [[ -z "$LinuxMirror" ]]; then
    echo -e "${RED}Error${NC}: Invaild mirror!"
    [ "$Release" == 'debian' ] && echo -e "${YELLOW}example:${NC} http://deb.debian.org/debian";
    [ "$Release" == 'ubuntu' ] && echo -e "${YELLOW}example:${NC} http://archive.ubuntu.com/ubuntu";
    exit 1;
fi

# check UEFI {{{
if [ -d "/boot/efi" ]; then
    isUEFI="true"
fi

# init kernel version {{{
kernel="linux-image-$VER"
if [ "$VER" == amd64 ] || [ "$VER" == arm64 ]; then
    if [ "$isUEFI" == "false" ]; then
        kernel="linux-image-cloud-$VER"
    fi
fi
if [ "$DIST_NUM" -ge 9 ]; then
    preInstall="$kernel/$DIST-backports $preInstall"
else
    echo 'backports kernel is only available for debian >= 9, not use it'
    preInstall="$kernel/$DIST $preInstall"
fi

# check DIST valid {{{
FindDist=0
DistsList=$(wget --no-check-certificate -qO- $LinuxMirror/dists | grep -Po '(?<=href=").*?(?=/")')
for CheckDist in $DistsList
do
    if [ "$CheckDist" == "$DIST" ]; then
        FindDist=1
        break
    fi
done
if [ $FindDist -eq 0 ]; then
    echo -e "${RED}Error${NC}: The dist version not found, Please check it!"
    exit 1;
fi
echo -e Install ${CYAN}$Release-$DIST-$kernel${NC}, mirror: ${CYAN}$LinuxMirror${NC}, current os: $currentRelease

# password {{{
if [ -z "$myPASSWORD" ]; then
    myPASSWORD='$1$P5AU4SN7$WPszMRmeWSTjOWUE/dCsR0'
else
    myPASSWORD="$(openssl passwd -1 $myPASSWORD)"
fi


# get network {{{
echo -e "${CYAN}get network info${NC}"
if [ -n "$ipAddr" ] && [ -n "$ipMask" ] && [ -n "$ipGate" ]; then
    IPv4="$ipAddr"
    MASK="$ipMask"
    GATE="$ipGate"
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

echo -e IPv4: $IPv4, NETMASK: $MASK, GATEWAY: $GATE
if [ -z "$GATE" ] || [ -z "$MASK" ] || [ -z "$IPv4" ]; then
    echo -e "${RED}Error${NC}: Not configure network."
    exit 1
fi


# check memory {{{
memory=$(free -k | grep Mem | awk '{print $2}')
echo -e "memory is $memory (free -k)"
if [ "$DIST" == "buster" ]; then
    if [ "$memory" -lt 299684 ]; then
        echo -e "low memory: $memory, need 299684 at least"
        exit 1
    fi
elif [ "$DIST" == "stretch" ]; then
    if [ "$memory" -lt 170660 ]; then
        echo -e "low memory: $memory, need 170660 at least"
        exit 1
    fi
elif [ "$DIST" == "bullseye" ]; then
    if [ "$memory" -lt 461476 ]; then
        echo -e "low memory: $memory, need 461476 at least"
        exit 1
    fi
fi


# download boot file {{{
TEST=${TEST:-"0"}
if [[ "$Release" == "debian" ]] || [[ "$Release" == "ubuntu" ]]; then
    echo -e "download ${CYAN}initrd.gz vmlinuz${NC} from ${CYAN}$netbootURL${NC}"
    if [ "$TEST" == "0" ]; then
        wget --no-check-certificate -qO "/boot/vmlinuz" $netbootURL/linux
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error${NC}: Download 'vmlinuz' failed!" && exit 1
        fi

        wget --no-check-certificate -qO "/boot/initrd.img" $netbootURL/initrd.gz
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error${NC}: Download 'initrd.img' failed!" && exit 1
        fi
    fi
else
    echo -e "${RED}Error${NC}: Invalid version $Release."
    exit 1
fi


# modify grub {{{
echo -e "${CYAN}set new grub${NC}"
if [ -f "/boot/grub/grub.cfg" ]; then
    GRUBVER=0 && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg'
elif [ -f "/boot/grub2/grub.cfg" ]; then
    GRUBVER=0 && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg'
elif [ -f "/boot/grub/grub.conf" ]; then
    GRUBVER=1 && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf'
else
    echo -e "${RED}Error${NC}: grub not found."
    exit 1
fi

saved_entry=""
GRUBNEW='/tmp/grub.new'
if [ "$GRUBVER" -eq 0 ]; then
    if [ "$(grep -Pc 'menuentry\ .*?{' $GRUBDIR/$GRUBFILE)" -ne 0 ]; then
        # get menuentry
        cat $GRUBDIR/$GRUBFILE | sed -n ':a;N;$!ba;s/\n/%%%%%/g;$p' | grep -Po 'menuentry\ .*?}%%%%%' | head -1 | sed 's/%%%%%/\n/g' >$GRUBNEW
        if [ ! -f $GRUBNEW ]; then
            echo -e "${RED}Error${NC}: $GRUBFILE have not menuentry."
            exit 1
        fi
        sed -i "s/menuentry.*/menuentry 'Install OS [$DIST $VER]' --class debian --class gnu-linux --class gnu --class os {/g" $GRUBNEW
        sed -i "/echo.*Loading/d" $GRUBNEW
        INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE | head -1)"
    else
        # check if use /boot/loader/entries, for centos8
        saved_entry=$(cat $GRUBDIR/grubenv | grep "saved_entry" | awk -F= '{print $2}')
        if [ -f "/boot/loader/entries/${saved_entry}.conf" ]; then
            cat "/boot/loader/entries/${saved_entry}.conf" > $GRUBNEW
        else
            echo -e "${RED}Error${NC}: saved_entry ${saved_entry} can't find."
            exit 1
        fi
        sed -i "s/title .*/title Install OS [$DIST $VER]/g" $GRUBNEW
    fi

elif [ "$GRUBVER" -eq 1 ]; then
    # for centos 6
    CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >$GRUBNEW
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >$GRUBNEW
    if [ ! -f $GRUBNEW ]; then
        echo -e "${RED}Error${NC}: $GRUBFILE config failed."
        exit 1
    fi
    sed -i "/title.*/c\title\ \'Install OS \[$DIST\ $VER\]\'" $GRUBNEW
    sed -i '/^#/d' $GRUBNEW;
    INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
fi

LinuxKernel="$(grep 'linux.*/\|kernel.*/' $GRUBNEW |awk '{print $1}')"
if [ -z "$LinuxKernel" ]; then
    echo -e "${RED}Error${NC}: can't find LinuxKernel."
    exit 1
fi
LinuxIMG="$(grep 'initrd.*/' $GRUBNEW |awk '{print $1}')";
if [ -z "$LinuxIMG" ]; then
    sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" $GRUBNEW
    LinuxIMG='initrd'
fi

BOOT_OPTION=" auto=true"
if [[ "$setInterfaceName" == "1" ]]; then
    BOOT_OPTION="$BOOT_OPTION net.ifnames=0 biosdevname=0"
fi

if [[ "$setIPv6" == "0" ]]; then
    BOOT_OPTION="$BOOT_OPTION ipv6.disable=1"
fi

if [[ "$Release" == 'debian' ]] || [[ "$Release" == 'ubuntu' ]]; then
    BOOT_OPTION="$BOOT_OPTION lowmem/low=true -- quiet"
fi

if [ -n "$(grep 'linux.*/\|kernel.*/' $GRUBNEW | awk '{print $2}' | grep '^/boot/')" ]; then
    inBoot="/boot"
else
    inBoot=""
fi

# add BOOT_OPTION boot failed on centos8
if [ "$currentRelease" == "centos" ]; then
    BOOT_OPTION=""
fi

sed -i "s|$LinuxKernel.*/.*|$LinuxKernel\t$inBoot/vmlinuz$BOOT_OPTION|g" $GRUBNEW
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
echo -e "${CYAN}unpack initrd${NC}"
rm -rf /tmp/boot && mkdir /tmp/boot && cd /tmp/boot
gzip -d < /boot/initrd.img | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1


# preseed.cfg {{{
if [[ "$Release" == 'debian' ]] || [[ "$Release" == 'ubuntu' ]]; then
    cat >/tmp/boot/preseed.cfg<<EOF
d-i debian-installer/locale string en_US
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale select en_US.UTF-8

d-i keymap select us

d-i netcfg/choose_interface select $interface

d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
d-i netcfg/get_ipaddress string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string 8.8.8.8
d-i netcfg/confirm_static boolean true

d-i netcfg/get_hostname string $(hostname)
d-i netcfg/get_domain string unassigned-domain

d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string $MirrorHost
d-i mirror/http/directory string $MirrorFolder
d-i mirror/http/proxy string
d-i apt-setup/services-select multiselect updates, backports
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true

d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $myPASSWORD
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
in-target sed -i '/MaxAuthTries/d' /etc/ssh/sshd_config; \
in-target bash -c "echo 'MaxAuthTries 10' | tee -a /etc/ssh/sshd_config"; \
in-target sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config; \
in-target sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;

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

fi  # preseed.cfg }}}


echo -e "${CYAN}create new initrd${NC}"
rm -f /boot/initrd.img
find . | cpio -H newc --create | gzip -9 > /boot/initrd.img
rm -rf /tmp/boot


echo -e "${CYAN}reboot && enter auto install, wait a moment, you can check process with VNC.${NC}"
sleep 3
reboot
