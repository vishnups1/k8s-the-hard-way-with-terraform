resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "k8s_the_hard_way_vpc" {
  name                    = "kubernetes-the-hard-way"
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.compute_api
  ]
}

resource "google_compute_subnetwork" "k8s_the_hard_way_subnet" {
  name          = "kubernetes-the-hard-way"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-west1"
  network       = google_compute_network.k8s_the_hard_way_vpc.id
}

resource "google_compute_firewall" "k8s_internal_firewall" {
  name    = "kubernetes-the-hard-way-internal"
  network = google_compute_network.k8s_the_hard_way_vpc.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = [
    "10.0.1.0/24", "10.200.0.0/16"
  ]
}

resource "google_compute_firewall" "k8s_external_firewall" {
  name    = "kubernetes-the-hard-way-external"
  network = google_compute_network.k8s_the_hard_way_vpc.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [
      "22",
      "6443"
    ]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]
}

resource "google_compute_address" "k8s_the_hard_way_lb" {
  name   = "kubernetes-the-hard-way-lb"
  region = "us-central1"
}

output "k8s_the_hard_way_lb_ip" {
  value = google_compute_address.k8s_the_hard_way_lb.address
}

resource "google_compute_instance" "k8s_the_hard_way_controlplane" {
  count = 3

  name                      = "k8s-the-hard-way-controlplane-${count.index}"
  can_ip_forward            = true
  machine_type              = "e2-standard-2"
  zone                      = "us-west1-a"
  tags                      = ["k8s-the-hard-way", "controller"]
  allow_stopping_for_update = true

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "centos-stream-8-v20230912"
      labels = {
        "k8s-the-hard-way-controlplane" = "true"
      }
      size = "100"
    }
  }

  network_interface {
    network    = google_compute_network.k8s_the_hard_way_vpc.id
    subnetwork = google_compute_subnetwork.k8s_the_hard_way_subnet.id
    network_ip = "10.0.1.1${count.index}"
  }
}

resource "google_compute_instance" "k8s_the_hard_way_workers" {
  count = 3

  name                      = "k8s-the-hard-way-worker-${count.index}"
  can_ip_forward            = true
  machine_type              = "e2-standard-2"
  zone                      = "us-west1-a"
  tags                      = ["k8s-the-hard-way", "worker"]
  allow_stopping_for_update = true
  metadata = {
    "pod-cidr" = "10.200.${count.index}.0/24"
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "centos-stream-8-v20230912"
      labels = {
        "k8s-the-hard-way-worker" = "true"
      }
      size = "100"
    }
  }

  network_interface {
    network    = google_compute_network.k8s_the_hard_way_vpc.id
    subnetwork = google_compute_subnetwork.k8s_the_hard_way_subnet.id
    network_ip = "10.0.1.2${count.index}"
  }
}