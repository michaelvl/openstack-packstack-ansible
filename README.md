Ansible playbook for an OpenStack PoC deployment.

The deployment is based on packstack and thus requires a host (physical or VM)
based on Centos.

The role provider-network-config configures a flat provider network for
integration with a flat external network.

The smoketest.sh script implements a simple test using two server instances with
floating IPs and a connectivity test between them.