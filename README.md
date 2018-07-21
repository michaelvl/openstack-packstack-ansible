## Ansible playbook for an OpenStack PoC deployment.

The deployment is based on packstack and thus requires a host (physical or VM)
based on Centos.  Update `hosts.yml` with appropriate credentials for your
OpenStack hosts.

The role provider-network-config configures a flat provider network for
integration with a flat external network.

The `tests/smoketest.sh` script implements a simple test using two server
instances with floating IPs and a connectivity test between them. The script
provides arguments `-c` to create an infrastructure, `-t` to run basic e2e test
on the infrastrcuture and `-d` to delete the infrastrcuture.

An alternative approach to building the test infrastructure is the Terraform
infrastructure description in `tests/smoketest.tf`. This replaces the create and
delete operations of the `smoketest.sh` script, however, the test operation is
still usefull for testing the infrastructure deployed by Terraform.