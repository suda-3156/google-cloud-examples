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

resource "google_service_account" "run-app" {
  project     = google_project.main.project_id
  account_id  = "run-app-sa"
  description = "Service Account for Cloud Run App"
}

resource "google_cloud_run_v2_service" "app" {
  for_each = toset(var.regions)

  project  = google_project.main.project_id
  location = each.key
  name     = "app"

  template {
    service_account = google_service_account.run-app.email
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
