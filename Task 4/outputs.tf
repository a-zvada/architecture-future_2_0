output "vpc_id" {
  value = yandex_vpc_network.data_mesh.id
}

output "private_subnet_id" {
  value = yandex_vpc_subnet.private.id
}

output "vm_internal_ips" {
  value = {
    for k, v in yandex_compute_instance.domain_vms : k => v.network_interface.0.ip_address
  }
}