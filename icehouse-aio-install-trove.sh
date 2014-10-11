#!/bin/bash -ex
# Script installation TROVE (dababase as a service) on Ubuntu 14.04
# You must complete instal other script or install component of OpenStack, include: Keystone, Glacne, Nova, Neutron, Horizon.
# You can download script or follow guide in here
#############################################
# Thanks you: 
# @Hoang Dinh Quan, 
# VietStacker: 
#############################################



sudo apt-get update -y

echo "Install trove-guestagent"
sleep 3

sudo apt-get install rsync trove-guestagent -y

sudo vi /etc/init/trove-guestagent.conf \
--exec /usr/bin/trove-guestagent -- --config-file=/etc/guest_info \
--config-file=/etc/trove/trove-guestagent.conf --log-dir=/var/log/trove \
--logfile=guestagent.log

cat << EOF >> /etc/init/trove-guestagent.conf 
[DEFAULT]
rabbit_host = $RABBITMQ-SERVER
rabbit_password = $RABBITMQ-PASSWORD
rabbit_userid = guest
verbose = True
debug = False
bind_port = 8778
bind_host = 0.0.0.0
nova_proxy_admin_user = admin
nova_proxy_admin_pass = $ADMIN_PASSWORD
nova_proxy_admin_tenant_name = admin
trove_auth_url = http://$KEYSTONE_SERVER:35357/v2.0
control_exchange = trove
root_grant = ALL
root_grant_option = True
ignore_users = os_admin
ignore_dbs = lost+found, mysql, information_schema
EOF

sudo chmod 755 /var/log/trove
sudo visudo trove ALL = (ALL) NOPASSWD: ALL

######################

echo "Create local datasource for instace's cloud-init"
sleep 3

# wget http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img

# echo "Create local datasource for instace's cloud-init"
# cat > my-user-data << EOF
# #cloud-config
# password: 'passw0rd'
# chpasswd: { expire: False }
# ssh_pwauth: True
# EOF

# cloud-localds my-seed.img my-user-data
