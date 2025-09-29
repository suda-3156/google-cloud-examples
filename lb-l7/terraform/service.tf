resource "google_project" "main" {
  name            = "${var.project_id_prefix}-service"
  project_id      = "${var.project_id_prefix}-service"
  billing_account = data.google_billing_account.billing.id
  folder_id       = var.folder_id

  # TODO
  deletion_policy = "DELETE"
}

# Timeout
resource "time_sleep" "wait_for_project" {
  create_duration = "60s"
  depends_on      = [google_project.main]
}

# api
locals {
  apis = [
    "run.googleapis.com",
  ]
}

resource "google_project_service" "main" {
  for_each = toset(local.apis)

  project            = google_project.main.project_id
  service            = each.key
  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_project]
}

locals {
  run_suffix = ["a", "b", "c"]
}

resource "google_service_account" "run" {
  for_each = toset(local.run_suffix)

  project      = google_project.main.project_id
  account_id   = "${var.project_id_prefix}-run-${each.key}"
  display_name = "${var.project_id_prefix}-run-${each.key}"
  description  = "Service Account for ${var.project_id_prefix}-run-${each.key}"
}

resource "google_cloud_run_v2_service" "main" {
  for_each = toset(local.run_suffix)

  project  = google_project.main.project_id
  location = var.region
  name     = "${var.project_id_prefix}-run-${each.key}"

  template {
    service_account = google_service_account.run[each.key].email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
    }
  }

  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  invoker_iam_disabled = true

  # TODO
  deletion_protection = false
  depends_on          = [google_project_service.main]
}
