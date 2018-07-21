#!/bin/bash

set -e
set -x

external_net=external_net
image=cirros

function smoketest() {

    echo "Checking dependencies"
    
    imgs=$(openstack image list | grep $image | wc -l)
    if [ $imgs = "0" ]; then
	echo "Requires image $image"
	exit 1
    fi

    echo "Creating network"

    openstack network create smoke_net
    openstack subnet create --dhcp --network smoke_net --subnet-range 10.1.1.0/24 smoke_subnet
    NETWORK_ID=$(openstack network list | grep smoke_net | awk '{print $2}')

    echo "Creating router"

    openstack router create --enable smoke_router
    openstack router set --external-gateway $external_net smoke_router
    openstack router add subnet smoke_router smoke_subnet

    openstack router list

    echo "Creating security group"

    openstack security group create ssh-access
    openstack security group rule create --ingress --protocol tcp --dst-port 22 ssh-access
    openstack security group rule create --egress --protocol tcp --dst-port 22 ssh-access

    openstack security group list

    echo "Creating instances"

    openstack server create --flavor m1.tiny --image $image --nic net-id=$NETWORK_ID --security-group ssh-access smoke_server0
    openstack server create --flavor m1.tiny --image $image --nic net-id=$NETWORK_ID --security-group ssh-access smoke_server1

    ip0=$(openstack floating ip create $external_net | grep ' floating_ip_address ' | awk '{print $4}')
    ip1=$(openstack floating ip create $external_net | grep ' floating_ip_address ' | awk '{print $4}')

    openstack server add floating ip smoke_server0 $ip0
    openstack server add floating ip smoke_server1 $ip1
}


function delete_all() {
    echo "Deleting resources"

    openstack server delete smoke_server0
    openstack server delete smoke_server1

    openstack router remove subnet smoke_router smoke_subnet
    openstack router delete smoke_router
    openstack subnet delete smoke_subnet
    openstack network delete smoke_net

    openstack security group delete ssh-access
    
    echo "Deleted smoketest instances"
}


function e2e_test() {

    set +e
    
    echo "Checking dependencies"

    which sshpass
    if [ $? -ne 0 ]; then
	echo "*** Requires sshpass utility"
	exit 1
    fi
    nets=$(openstack network list | grep $external_net | wc -l)
    if [ $nets = "0" ]; then
	echo "Requires external net $external_net"
	exit 1
    fi
    insts=$(openstack server list | grep smoke_server | wc -l)
    if [ $insts != "2" ]; then
	echo "Requires two running server instances"
	exit 1
    fi

    echo "Running e2e test"

    server0=$(openstack server list | grep smoke_server0)
    ip0=$(echo $server0 | awk '{print $9}')
    iip0=$(echo $server0 | awk '{gsub("smoke_net=","");gsub(",","");print $8}')
    echo "Server0 ip=$ip0, internal ip=$iip0"
    server1=$(openstack server list | grep smoke_server1)
    ip1=$(echo $server1 | awk '{print $9}')
    iip1=$(echo $server1 | awk '{gsub("smoke_net=","");gsub(",","");print $8}')
    echo "Server1 ip=$ip1, internal ip=$iip1"

    echo "Testing connectivity using floating IPs"
    sshpass -p gocubsgo ssh -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null cirros@$ip0 nc -z -w2 $ip1 22
    if [ $? -ne 0 ]; then
	echo "*** No connectivity found"
	exit 1
    fi
    sshpass -p gocubsgo ssh -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null cirros@$ip0 nc -z -w2 $ip1 23
    if [ $? -eq 0 ]; then
	echo "*** Unexpected connectivity found"
	exit 1
    fi

    echo "Testing connectivity using private IPs"
    sshpass -p gocubsgo ssh -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null cirros@$ip0 nc -z -w2 $iip1 22
    if [ $? -ne 0 ]; then
	echo "*** No connectivity found"
	exit 1
    fi


    echo "End2end test OK"
}


while [ $# -ne 0 ]
do
    arg="$1"
    case "$arg" in
	-c)
	    smoketest
	    ;;
	-d)
	    delete_all
	    ;;
	-t)
	    e2e_test
	    ;;
    esac
    shift
done
