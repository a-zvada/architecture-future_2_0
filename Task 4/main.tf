# ==================== VPC & NETWORK ====================
resource "yandex_vpc_network" "data_mesh" {
  name = "data-mesh-vpc"
}

# Одна публичная подсеть (для NAT и bastion при необходимости)
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.data_mesh.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

# Одна приватная подсеть
resource "yandex_vpc_subnet" "private" {
  name           = "private-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.data_mesh.id
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}

# ==================== NAT Gateway ====================
resource "yandex_vpc_gateway" "nat" {
  name = "nat-gateway"
}

resource "yandex_vpc_route_table" "private" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.data_mesh.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# ==================== Security Group ====================
resource "yandex_vpc_security_group" "data_mesh_sg" {
  name       = "data-mesh-sg"
  network_id = yandex_vpc_network.data_mesh.id

  # Inbound
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH"
  }

  ingress {
    protocol       = "TCP"
    from_port      = 80
    to_port        = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HTTP/HTTPS (для теста)"
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "ICMP"
  }

  # Outbound — всё разрешено
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "All outbound"
  }
}

# ==================== VM по доменам ====================
resource "yandex_compute_instance" "domain_vms" {
  for_each = toset(var.domains)

  name        = "${each.key}-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd81radk00nmm2jpqh94" # Ubuntu 22.04 LTS
      size     = 20
      type     = "network-ssd"
    }
  }

  # Дополнительный диск 100 ГБ под данные lakehouse
  secondary_disk {
    disk_id = yandex_compute_disk.data_disk[each.key].id
  }

  network_interface {
    subnet_id         = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.data_mesh_sg.id]
    nat               = false
  }

  metadata = {
    user-data = <<EOF
#cloud-config
users:
  - name: ${var.vm_user}
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${var.ssh_public_key}
EOF
  }
}

# ==================== Диски под данные ====================
resource "yandex_compute_disk" "data_disk" {
  for_each = toset(var.domains)

  name = "${each.key}-data-disk"
  size = 10
  type = "network-ssd"
  zone = "ru-central1-a"
}