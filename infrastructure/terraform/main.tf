provider "google" {
  project = "conxian-sovereign"
  region  = "us-central1"
}

resource "google_compute_instance" "gateway_node" {
  name         = "conxian-gateway-prod"
  machine_type = "e2-standard-4"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    "conclave-ethos" = "TEE-ENABLED"
    "bos-role"       = "GATEWAY"
  }

  tags = ["conxian-gateway", "sarb-compliant"]
}

output "gateway_ip" {
  value = google_compute_instance.gateway_node.network_interface[0].access_config[0].nat_ip
}
