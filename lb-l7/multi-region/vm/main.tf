# ルーティングの検証用のVM
resource "google_project" "vm" {
  name            = "${var.project_id_prefix}-vm"
  project_id      = "${var.project_id_prefix}-vm"
  billing_account = data.google_billing_account.billing.id
  folder_id       = var.folder_id

  # TODO
  deletion_policy = "DELETE"
}

# Timeout
resource "time_sleep" "wait_for_vm_project" {
  create_duration = "60s"
  depends_on      = [google_project.vm]
}

# api
locals {
  apis = [
    "compute.googleapis.com",
  ]
}
resource "google_project_service" "vm" {
  for_each = toset(local.apis)

  project            = google_project.vm.project_id
  service            = each.key
  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_vm_project]
}

resource "google_compute_network" "main" {
  name                    = "vm-network"
  project                 = google_project.vm.project_id
  auto_create_subnetworks = false

  depends_on = [google_project_service.vm]
}

resource "google_compute_subnetwork" "main" {
  for_each = toset(var.regions)

  name          = "vm-subnet-${each.key}"
  project       = google_project.vm.project_id
  region        = each.key
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.${index(var.regions, each.key)}.0/24"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_service_account" "vm" {
  for_each = toset(var.regions)

  account_id   = "vm-sa-${each.key}"
  display_name = "VM Service Account ${each.key}"
  project      = google_project.vm.project_id

  depends_on = [google_project_service.vm]
}

resource "google_compute_instance" "main" {
  for_each = toset(var.regions)

  name         = "vm-${each.key}"
  project      = google_project.vm.project_id
  zone         = "${each.key}-a"
  machine_type = "f1-micro"

  tags = ["ssh-access"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }

    # TODO
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.main[each.key].id

    # 外部IPアドレスを割り振る方法は次の2種類ある。静的外部IPアドレス、エフェメラル外部IPアドレス
    # 今回はエフェメラル外部IPアドレスを使うので、access_configの中は何も指定しない
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    email  = google_service_account.vm[each.key].email
    scopes = ["cloud-platform"]
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}

resource "google_compute_firewall" "ssh_access" {
  name    = "allow-ssh-access"
  project = google_project.vm.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["ssh-access"]

  # VMインスタンスへのSSH接続元IPアドレス範囲を指定する
  # 今使ってるグローバルIPアドレスだけを許可したい場合は
  # $ curl httpbin.org/ip
  # で取得したIPアドレスを指定する
  # （例: 123.123.123.123/32）
  source_ranges = var.ssh_access_source_ranges

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_project_iam_custom_role" "ssh-access-role" {
  project = google_project.vm.project_id
  role_id = "sshAccessRole"
  title   = "SSH Access Role"

  permissions = [
    "compute.projects.get",
    "compute.instances.get",
    "compute.instances.setMetadata",
    "iam.serviceAccounts.actAs",
  ]
}

resource "google_project_iam_binding" "vm-ssh-access-binding" {
  project = google_project.vm.project_id
  role    = google_project_iam_custom_role.ssh-access-role.name

  members = var.ssh_access_members
}
