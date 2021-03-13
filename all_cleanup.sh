semodule -r novaapi
semodule -r httpd
semodule -r glanceapi
semodule -r rabbitmqctl
semodule -r linuxbridgectl

sudo semanage port -d -p tcp 8778

firewall-cmd --permanent --remove-service={http,https,mysql}
firewall-cmd --permanent --remove-port={11211,8000,8004,5672,5000,9191,9292,6080,6081,6082,8774,8775,8778,8776,9696}/tcp
firewall-cmd --reload

yum erase -y mariadb-server mariadb rabbitmq-server python3-openstackclient memcached python3-memcached  openstack-keystone httpd python3-mod_wsgi python3-heatclient openstack-glance openstack-neutron openstack-neutron-ml2 openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler openstack-neutron-linuxbridge openstack-cinder openstack-placement-api openstack-dashboard openstack-heat-common openstack-heat-api openstack-heat-api-cfn openstack-heat-engine

rm -rf /etc/cinder/ /etc/glance/ /etc/httpd/ /etc/keystone/ /etc/my.cnf.d/ /etc/neutron/ /etc/nova/ /var/lib/cinder/ /var/lib/httpd/ /var/lib/keystone/ /var/lib/mysql/ /var/lib/glance/ /var/lib/nova/ /var/lib/openstack-dashboard/ /var/lib/neutron/ /etc/placement/ /etc/rabbitmq/ /var/lib/openvswitch/ /var/lib/rabbitmq/ /etc/sysconfig/openstack-nova-novncproxy /etc/sysconfig/memcached /home/stack/scripts/centos/*.{mod,pp,te}

