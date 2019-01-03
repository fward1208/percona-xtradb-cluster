#!/bin/bash
sleep 60
until apt update &&  apt-get install iproute pmm-client cron -y; do echo "Retrying"; sleep 2; done
rm -rf /var/cache/yum

ipaddr=$(hostname -i | awk ' { print $1 } ')
sleep 10
# on first join, pmm-admin forces the use of the ip address. the second config setup adds the host as the mapping
pmm-admin config --server pmmserver:443 --server-user pmm --server-password pmm --server-insecure-ssl --force --client-address $(hostname)
pmm-admin check-network
pmm-admin add mysql --host $HOSTNAME --user root --password D1splay@dmin --query-source perfschema $(hostname)
