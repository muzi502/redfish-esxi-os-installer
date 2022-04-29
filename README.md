# redfish-esxi-os-installer

## Support vendor

- HPE [Redfish API implementation on HPE servers with iLO RESTful API technical white paper](https://www.hpe.com/psnow/doc/4AA6-1727ENW)
- Dell [Support for Dell EMC OpenManage Ansible Modules](https://www.dell.com/support/kbdoc/zh-hk/000177308/dell-emc-openmanage-ansible-modules)
- Lenovo [Lenovo XClarity Controller Redfish REST API](https://sysmgt.lenovofiles.com/help/index.jsp?topic=%2Fcom.lenovo.systems.management.xcc.doc%2Frest_api.html)

## Usage

### install requirements tools

- curl
- make
- rsync
- genisoimage
- [yq](https://github.com/mikefarah/yq)
- [govc](https://github.com/vmware/govmomi/tree/master/govc)
- HTTP server, such as [nginx](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/)
- NFS server

### Config HTTP server

1. Copy VMware-VMvisor-Installer-xxx.iso ISO file to the HTTP server static file directory.

```bash
/usr/share/nginx/html/iso/
├── VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso
├── VMware-VMvisor-Installer-7.0U2a-17867351.x86_64.iso
└── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso
```

### Config NFS server (option)

Config NFS `/etc/exports` shared directories for Jenkins Job

```
/usr/share/nginx/html	*(rw,anonuid=0,anongid=0,all_squash,sync)
```

### filed config.yaml file

```
$ cp config-example.yaml config.yaml
$ vim config.yaml
```

config.yaml example

```yaml
hosts:
- ipmi:
    vendor: lenovo                  # vendor name [dell, lenovo, hpe]
    address: 10.172.70.186          # IPMI address
    username: username              # IPMI username
    password: password              # IPMI password
  esxi:
    esxi_disk: ThinkSystem M.2      # ESXi os disk model or WWN ID
    password: password              # ESXi root user password
    address: 10.172.69.86           # ESXi Management Network IP address
    gateway: 10.172.64.1            # ESXi Management Network gateway
    netmask: 255.255.240.0          # ESXi Management Network netmask
    hostname: esxi-69-86            # ESXi hostname (option)
    mgtnic: vmnic4                  # ESXi vSwitch0's nic device, can be set to vmnic name or mac address

- ipmi:
    vendor: dell
    address: 10.172.18.191
    username: username
    password: password
  esxi:
    esxi_disk: DELLBOSS VD
    password: password
    address: 10.172.18.95
    gateway: 10.172.16.1
    netmask: 255.255.240.0
    mgtnic: B9:96:91:A7:3F:D6
```

### generate ansible inventory file

Make sure has installed [yq]() command, and just run `make inventory` command. After that, it will generate an ansible inventory file `inventory.ini`.

```ini
[hpe]
10.172.18.191 username=username password=password esxi_address=10.172.18.95 esxi_password=password

[dell]
10.172.18.192 username=username password=password esxi_address=10.172.18.96 esxi_password=password

[lenovo]
10.172.18.193 username=username password=password esxi_address=10.172.18.97 esxi_password=password

[all:children]
hpe
dell
lenovo
```

### Precheck redfish login

make pre-check

### build ESXi ISO

make build-iso

### mount-iso

### reboot

### post-check

## Jenkins Job

## Blogs
