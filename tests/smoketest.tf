variable "instance_count" {
  default = 2
}

provider "openstack" {
  region = "RegionOne"
}

data "openstack_compute_flavor_v2" "flv" {
  name = "m1.tiny"
  #name = "m1.medium"
}

data "openstack_images_image_v2" "img" {
  name = "cirros"
  #name = "kubeimg-1.11.0-20180701-2241"
}

data "openstack_networking_network_v2" "external_net" {
  name = "external_net"
}


resource "openstack_networking_router_v2" "smoke_router" {
  name                = "smoke_router"
  admin_state_up      = true
  external_network_id = "${data.openstack_networking_network_v2.external_net.id}"
}


resource "openstack_networking_network_v2" "smoke_net" {
  name           = "smoke_net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "smoke_subnet" {
  name       = "smoke_subnet"
  network_id = "${openstack_networking_network_v2.smoke_net.id}"
  cidr       = "10.1.1.0/24"
  ip_version = 4
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.smoke_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.smoke_subnet.id}"
}


resource "openstack_networking_secgroup_v2" "ssh_access" {
  name        = "ssh_access"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.ssh_access.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_2" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.ssh_access.id}"
}


resource "openstack_networking_floatingip_v2" "floatip" {
  pool  = "${data.openstack_networking_network_v2.external_net.name}"
  count = "${var.instance_count}"
}

resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  count       = "${var.instance_count}"
  floating_ip = "${element(openstack_networking_floatingip_v2.floatip.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.smoke.*.id, count.index)}"
}


resource "openstack_compute_instance_v2" "smoke" {
  count           = "${var.instance_count}"
  name            = "smoke_server${count.index}"
  flavor_id       = "${data.openstack_compute_flavor_v2.flv.id}"
  image_id        = "${data.openstack_images_image_v2.img.id}"
  security_groups = ["${openstack_networking_secgroup_v2.ssh_access.name}"]

  network {
    name = "smoke_net"
  }
}