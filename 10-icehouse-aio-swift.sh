#!/bin/bash -ex
source config-after-neutron.cfg

SWIFT

echo "##### TAO USER, ROLE, SERVICE, ENDPOINT #####"
# Tao user
# keystone user-create --name=swift --pass=SWIFT_PASS --email=swift@example.com

# Add role cho user
# keystone user-role-add --user=swift --tenant=service --role=admin

# Tao service ten la swift
keystone service-create --name=swift --type=object-store \
--description="OpenStack Object Storage"

# Tao ENDPOINT
keystone endpoint-create \
--region RegionOne \
--service-id=$(keystone service-list | awk '/ object-store / {print $2}') \
--publicurl=http://192.168.56.130:8080/v1/AUTH_%\(tenant_id\)s \
--internalurl=http://192.168.56.130:8080/v1/AUTH_%\(tenant_id\)s \
--adminurl=http://192.168.56.130:8080


echo "##### CAU HINH CHO SWIFT #####"
# Tạo folder cấu hình 
 mkdir -p /etc/swift
 
# Tạo /etc/swift/swift.conf
cat << EOF >> /etc/swift/swift.conf
[swift-hash]
# random unique string that can never change (DO NOT LOSE)
swift_hash_path_suffix = fLIbertYgibbitZ
EOF

echo "##### Cài đặt các thành phần storage #####"
sudo apt-get install swift swift-account swift-container swift-object xfsprogs -y 

#  Format phân vùng cho Swift về XFS
# 

# fdisk /dev/sdc
(echo o; echo n; echo p; echo 1; echo ; echo; echo w) | sudo fdisk /dev/sdc
echo "/dev/sdc1 /srv/node/sdc1 xfs noatime,nodiratime,nobarrier,logbufs= 8 0 0" >> /etc/fstab

mkfs.xfs /dev/sdc1
mkdir -p /srv/node/sdc1
mount /dev/sdc1 /srv/node/sdc1
# mount /srv/node/sdb1
chown -R swift:swift /srv/node

echo "##### Tạo file /etc/rsyncd.conf ####"
sleep 3
cat << EOF >> /etc/rsyncd.conf
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $LOCAL_IP

[account]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/object.lock
EOF

# Sửa file /etc/default/rsync
sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync

#  Khởi động lại rsync service
service rsync start

#  Tạo thư mục swift recon cache và gán quyền
mkdir -p /var/swift/recon
chown -R swift:swift /var/swift/recon

echo "##### Cài đặt dịch vụ swift-proxy #####"
sleep 3
apt-get install swift-proxy memcached python-keystoneclient python-swiftclient python-webob -y

# Sửa file /etc/memcached.conf để memcached lắng nghe local interface
sed -i 's/-l 127.0.0.1/-l $LOCAL_IP/g' /etc/memcached.conf 

# Khởi động lại memcached
service memcached restart

# Tạo file /etc/swift/proxy-server.conf

cat << EOF >> /etc/swift/proxy-server.conf
[DEFAULT]
bind_port = 8080
user = swift
[pipeline:main]
pipeline = healthcheck cache authtoken keystoneauth proxy-server
[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true
[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = Member,admin,swiftoperator
[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
# Delaying the auth decision is required to support token-less
# usage for anonymous referrers ('.r:*').
delay_auth_decision = true
# cache directory for signing certificate
# signing_dir = /home/swift/keystone-signing
# auth_* settings refer to the Keystone server
auth_protocol = http
auth_host = $MASTER
auth_port = 35357
# the service tenant and swift username and password created in Keystone
admin_tenant_name = service
admin_user = swift
admin_password = Welcome123
[filter:cache]
use = egg:swift#memcache
[filter:catch_errors]
use = egg:swift#catch_errors
[filter:healthcheck]
use = egg:swift#healthcheck
EOF

echo "##### Tạo account, container và object ring #####"
sleep 3 
cd /etc/swift
swift-ring-builder account.builder create 18 3 1
swift-ring-builder container.builder create 18 3 1
swift-ring-builder object.builder create 18 3 1

echo "##### Thêm entry cho các ring #####"
sleep 3 
swift-ring-builder account.builder add z1-$LOCAL_IP:6002/sdc1 100
swift-ring-builder container.builder add z1-$LOCAL_IP:6001/sdc1 100
swift-ring-builder object.builder add z1-$LOCAL_IP:6000/sdc1 100

echo "##### Kiểm tra lại ring content #####"
sleep 3
swift-ring-builder account.builder
swift-ring-builder container.builder
swift-ring-builder object.builder

echo "##### Rebalance các ring #####"
sleep 3

swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

cd /root

#  Gán quyền cho user Swift sở hữu các file cấu hình
chown -R swift:swift /etc/swift

echo "##### Khởi động lại các dịch vụ phu tro #####"
sleep 3

swift-init proxy start
swift-init main start
service rsyslog restart
service memcached restart

echo "##### Khởi động lại các dịch vụ Swift #####"
sleep 3

for service in \
swift-object swift-object-replicator swift-object-updater swift-object-auditor \
swift-container swift-container-replicator swift-container-updater swift-container-auditor \
swift-account swift-account-replicator swift-account-reaper swift-account-auditor; do \
service $service start; done

echo "##### Kiem tra viec cai dat SWIFT #####"
sleep 3

swift stat
echo "##### Cai dat thanh cong #####"


