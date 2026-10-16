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

resource "yandex_compute_instance" "instahelper_prod" {
  name        = "prod-app-host"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my-ubuntu-2004-1.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet_prod.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "lab-net-prod" {
  name = "prod-network"
}

resource "yandex_vpc_subnet" "my_subnet_prod" {
  name           = "prod-subnet"
  v4_cidr_blocks = ["10.3.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.lab-net-prod.id
}

resource "yandex_dns_zone" "zone_prod" {
  name        = "prod-private-zone"
  zone             = "instahelper.com."
  public           = false
  private_networks = [yandex_vpc_network.lab-net-prod.id]
}

resource "yandex_dns_recordset" "prod_domain" {
  zone_id = yandex_dns_zone.zone_prod.id
  name    = "@"
  type    = "A"
  ttl     = 200
  data    = [yandex_lb_network_load_balancer.my_nlb_prod.listener[0].external_address_spec[0].address]
}


resource "yandex_lb_target_group" "my_tg_prod" {
  name      = "prod-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.my_subnet_prod.id
    address   = yandex_compute_instance.instahelper_prod.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "my_nlb_prod" {
  name = "prod-network-load-balancer"

  listener {
    name = "prod-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.my_tg_prod.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
