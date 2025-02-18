#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up Block Storage service controller (cinder controller node)
#------------------------------------------------------------------------------

sudo cd /etc/swift

sudo swift-ring-builder account.builder create 10 3 1
sudo swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.31 --port 6202 --device sdb --weight 100
sudo swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.31 --port 6202 --device sdc --weight 100
sudo swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6202 --device sdb --weight 100
sudo swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6202 --device sdc --weight 100

#------------------------------------------------------------------------------
# Verify the ring contents:
#------------------------------------------------------------------------------
sudo swift-ring-builder account.builder

#------------------------------------------------------------------------------
# Rebalance the ring:
#------------------------------------------------------------------------------
sudo swift-ring-builder account.builder rebalance

#------------------------------------------------------------------------------
# Create the base container.builder file:
#------------------------------------------------------------------------------
sudo swift-ring-builder container.builder create 10 3 1

#------------------------------------------------------------------------------
# Add each storage node to the ring:
#------------------------------------------------------------------------------

sudo swift-ring-builder container.builder add --region 1 --zone 1 --ip 10.0.0.31 --port 6201 --device sdb --weight 100
sudo swift-ring-builder container.builder add --region 1 --zone 1 --ip 10.0.0.31 --port 6201 --device sdc --weight 100
sudo swift-ring-builder container.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6201 --device sdb --weight 100
sudo swift-ring-builder container.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6201 --device sdc --weight 100

#------------------------------------------------------------------------------
# Verify the ring contents:
#------------------------------------------------------------------------------

sudo swift-ring-builder container.builder

#------------------------------------------------------------------------------
# Rebalance the ring:
#------------------------------------------------------------------------------

sudo swift-ring-builder container.builder rebalance

#------------------------------------------------------------------------------
# Create the base object.builder file:
#------------------------------------------------------------------------------

sudo swift-ring-builder object.builder create 10 3 1

#------------------------------------------------------------------------------
# Add each storage node to the ring:
#------------------------------------------------------------------------------

sudo swift-ring-builder object.builder add  --region 1 --zone 1 --ip 10.0.0.31 --port 6200 --device sdb --weight 100
sudo swift-ring-builder object.builder add --region 1 --zone 1 --ip 10.0.0.31 --port 6200 --device sdc --weight 100
sudo swift-ring-builder object.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6200 --device sdb --weight 100
sudo swift-ring-builder object.builder add --region 1 --zone 2 --ip 10.0.0.41 --port 6200 --device sdc --weight 100

#------------------------------------------------------------------------------
# Verify the ring contents:
#------------------------------------------------------------------------------

sudo swift-ring-builder object.builder

#------------------------------------------------------------------------------
# Rebalance the ring:
#------------------------------------------------------------------------------

sudo swift-ring-builder object.builder rebalance

#------------------------------------------------------------------------------
# Obtain the /etc/swift/swift.conf file from the Object Storage source repository:
#------------------------------------------------------------------------------

sudo curl -o /etc/swift/swift.conf \
  https://opendev.org/openstack/swift/raw/branch/master/etc/swift.conf-sample

conf=/etc/swift/swift.conf

iniset_sudo $conf swift-hash swift_hash_path_suffix TSPSuff12
iniset_sudo $conf swift-hash swift_hash_path_prefix TSPPre12
iniset_sudo $conf storage-policy:0 name Policy-0
iniset_sudo $conf storage-policy:0 default yes

sudo scp account.ring.gz compute:/etc/swift/
sudo scp container.ring.gz compute:/etc/swift/
sudo scp object.ring.gz compute:/etc/swift/
sudo scp swift.conf compute:/etc/swift/

sudo scp account.ring.gz storage:/etc/swift/
sudo scp container.ring.gz storage:/etc/swift/
sudo scp object.ring.gz storage:/etc/swift/
sudo scp swift.conf storage:/etc/swift/

node_ssh compute sudo chown -R root:swift /etc/swift
node_ssh storage sudo chown -R root:swift /etc/swift

sudo systemctl enable openstack-swift-proxy.service memcached.service
sudo systemctl start openstack-swift-proxy.service memcached.service 

for ringtype in account container object; do 
   node_ssh compute sudo systemctl start openstack-swift-$ringtype
   node_ssh compute  sudo systemctl enable openstack-swift-$ringtype
    for service in replicator updater auditor; do
        if [ $ringtype != 'account' ] || [ $service != 'updater' ]; then
          node_ssh compute sudo systemctl start openstack-swift-$ringtype-$service
          node_ssh compute sudo systemctl enable openstack-swift-$ringtype-$service
        fi
    done
done

for ringtype in account container object; do 
    node_ssh storage sudo systemctl start openstack-swift-$ringtype
    node_ssh storage sudo systemctl enable openstack-swift-$ringtype
    for service in replicator updater auditor; do
        if [ $ringtype != 'account' ] || [ $service != 'updater' ]; then
           node_ssh storage sudo systemctl start openstack-swift-$ringtype-$service
           node_ssh storage sudo systemctl enable openstack-swift-$ringtype-$service
        fi
    done
done

sudo systemctl restart httpd

