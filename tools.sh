#!/bin/bash
INPUT=$1
SRC_ISO=$2
set -o errexit
set -o nounset
set -o pipefail

: ${INPUT:=inventory}
: ${SRC_ISO:=${INPUT}}
: ${CONFIG:=config.yaml}
: ${INVENTORY:=inventory.ini}
: ${BUILD_TEMP_DIR:=/tmp/redfish-os-installer}
: ${DEST_ISO_DIR:=/usr/share/nginx/html}

readonly SRC_ISO_NAME=$(basename ${SRC_ISO/.iso/})
readonly SRC_ISO_MOUNT_DIR="${BUILD_TEMP_DIR}/${SRC_ISO_NAME}/iso"
readonly DEST_ISO_BUILD_DIR="${BUILD_TEMP_DIR}/${SRC_ISO_NAME}/.iso"

function gen_iso_ks(){
    local ISO_KS=$1
    local ESXI_DISK=${os_disk}
    local IP_ADDRESS=${esxi_address}
    local NETMASK=${esxi_netmask}
    local GATEWAY=${esxi_gateway}
    local DNS_SERVER="${GATEWAY}"
    local PASSWORD=${esxi_password}
    local HOSTNAME="$(echo ${esxi_hostname} | sed "s/null/esxi-${esxi_address//./-}/")"
    local MGTNIC=$(echo ${esxi_mgtnic} | tr '[a-z]' '[A-Z]' | sed 's/VMNIC/vmnic/g')
    cat << EOF > ${ISO_KS}
vmaccepteula

# Set the root password for the DCUI and Tech Support Mode
rootpw ${PASSWORD}

# Set the keyboard
keyboard 'US Default'

# wipe exisiting VMFS store # CAREFUL!
clearpart --alldrives --overwritevmfs

# Install on the first local disk available on machine
install --overwritevmfs --firstdisk="${ESXI_DISK}"

# Set the network to DHCP on the first network adapter
network --bootproto=static --hostname=${HOSTNAME} --ip=${IP_ADDRESS} --gateway=${GATEWAY} --nameserver=${DNS_SERVER} --netmask=${NETMASK} --device="${MGTNIC}"

reboot

%firstboot --interpreter=busybox

# Enable SSH
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
esxcli network firewall ruleset set --enabled=false --ruleset-id=sshServer
EOF

}

function rebuild_esxi_iso() {
    local dest_iso_mount_dir=$1
    local dest_iso_path=$2
    pushd ${dest_iso_mount_dir} > /dev/null
    sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' boot.cfg
    sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' efi/boot/boot.cfg
    genisoimage -J \
                -R  \
                -o ${dest_iso_path} \
                -relaxed-filenames \
                -b isolinux.bin \
                -c boot.cat \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                -eltorito-alt-boot \
                -eltorito-boot efiboot.img \
                -quiet --no-emul-boot \
                . > /dev/null
  popd > /dev/null
}

function rendder_host_info(){
    local index=$1
    vendor=$(yq -e eval ".hosts.[$index].ipmi.vendor" ${CONFIG})
    os_disk="$(yq -e eval ".hosts.[$index].esxi.esxi_disk" ${CONFIG})"
    esxi_mgtnic=$(yq -e eval ".hosts.[$index].esxi.mgtnic" ${CONFIG})
    esxi_address=$(yq -e eval ".hosts.[$index].esxi.address" ${CONFIG})
    esxi_gateway=$(yq -e eval ".hosts.[$index].esxi.gateway" ${CONFIG})
    esxi_netmask=$(yq -e eval ".hosts.[$index].esxi.netmask" ${CONFIG})
    esxi_password=$(yq -e eval ".hosts.[$index].esxi.password" ${CONFIG})
    ipmi_address=$(yq -e eval ".hosts.[$index].ipmi.address" ${CONFIG})
    ipmi_username=$(yq -e eval ".hosts.[$index].ipmi.username" ${CONFIG})
    ipmi_password=$(yq -e eval ".hosts.[$index].ipmi.password" ${CONFIG})
    esxi_hostname="$(yq -e eval ".hosts.[$index].esxi.hostname" ${CONFIG} 2> /dev/null || true)"
}

function gen_inventory(){
    cat << EOF > ${INVENTORY}
_hpe_

_dell_

_lenovo_

[all:children]
hpe
dell
lenovo
EOF

    for i in $(seq 0 `expr ${nums} - 1`); do
        rendder_host_info ${i}
        host_info="${ipmi_address} username=${ipmi_username} password=${ipmi_password} esxi_address=${esxi_address} esxi_password=${esxi_password}"
        sed -i "/_${vendor}_/a ${host_info}" ${INVENTORY}
    done
    sed -i "s#^_dell_#[dell]#g;s#^_lenovo_#[lenovo]#g;s#_hpe_#[hpe]#g" ${INVENTORY}
    echo "gen inventory success"
}

function exit_handler(){
    umount ${SRC_ISO_MOUNT_DIR} > /dev/null 2>&1
}

function main(
    readonly nums=$(yq eval ".hosts|length" ${CONFIG})
    if [[ ${nums} -lt 1 ]]; then
        echo "not found host in the ${CONFIG} file"
        exit 1
    fi
    if [[ $INPUT == "inventory" ]]; then
        gen_inventory
    elif [[ $INPUT == "build-iso" ]]; then
        trap exit_handler EXIT
        mkdir -p ${SRC_ISO_MOUNT_DIR} ${DEST_ISO_BUILD_DIR}
        mount -o loop ${SRC_ISO} ${SRC_ISO_MOUNT_DIR}
        rsync -avrut --force --stats --delete ${SRC_ISO_MOUNT_DIR}/ ${DEST_ISO_BUILD_DIR}/ > /dev/null
        for i in $(seq 0 `expr ${nums} - 1`); do
            rendder_host_info ${i}
            mkdir -p ${DEST_ISO_DIR}/${ipmi_address}
            gen_iso_ks ${DEST_ISO_BUILD_DIR}/KS.CFG
            rebuild_esxi_iso ${DEST_ISO_BUILD_DIR} ${DEST_ISO_DIR}/${ipmi_address}/${SRC_ISO_NAME}.iso
            echo "build ${DEST_ISO_DIR}/${ipmi_address}/${SRC_ISO_NAME}.iso success"
        done
    fi
)

main "$@"
