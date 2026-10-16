terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-b"
}



data "yandex_compute_image" "my-ubuntu-2004-1" {
  family = "ubuntu-2004-lts"
}


resource "yandex_compute_instance" "instahelper" {
  name        = "infra"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.my-ubuntu-2004-1.id}"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "gitlab_runner" {
  name        = "gitlab_runner"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.my-ubuntu-2004-1.id}"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "monitoring" {
  name        = "monitoring-server"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.my-ubuntu-2004-1.id}"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "lab-net" {
  name = "lab-network"
}

resource "yandex_vpc_subnet" "my_subnet" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.lab-net.id
}

resource "yandex_dns_zone" "zone1" {
  name        = "my-private-zone"
  description = "desc"

  labels = {
    label1 = "label-1-value"
  }

  zone             = "instahelper.com."
  public           = false
  private_networks = [yandex_vpc_network.lab-net.id]

  deletion_protection = false

  depends_on = [yandex_vpc_network.lab-net]
}

resource "yandex_dns_recordset" "rs1" {
  zone_id = yandex_dns_zone.zone1.id
  name    = "srv.instahelper.com."
  type    = "A"
  ttl     = 200
  data    = ["10.1.0.1"]
}

resource "yandex_lb_target_group" "my_tg" {
  name      = "my-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    address   = yandex_compute_instance.instahelper.network_interface.0.ip_address
  }

}

resource "yandex_dns_recordset" "monitoring_dns" {
  zone_id = yandex_dns_zone.zone1.id
  name    = "monitoring"
  type    = "A"
  ttl     = 200
  data    = [yandex_compute_instance.monitoring.network_interface.0.nat_ip_address]
}

resource "yandex_dns_recordset" "grafana_dns" {
  zone_id = yandex_dns_zone.zone1.id
  name    = "grafana"
  type    = "A"
  ttl     = 200
  data    = [yandex_compute_instance.monitoring.network_interface.0.nat_ip_address]
}

resource "yandex_lb_network_load_balancer" "my_nlb" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.my_tg.id # Исправили имя ссылки на целевую группу

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
