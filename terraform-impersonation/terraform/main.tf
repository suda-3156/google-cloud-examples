locals {
  envs = ["dev", "stg", "prod"]
}

resource "google_project" "service" {
  for_each = { for env in local.envs : env => "${var.project_id_prefix}-${env}" }

  name            = "${var.project_id_prefix}-${each.key}"
  project_id      = "${var.project_id_prefix}-${each.key}"
  billing_account = data.google_billing_account.billing.id
  folder_id       = var.folder_id

  # TODO
  deletion_policy = "DELETE"
}

locals {
  projects = { for env in local.envs : env => google_project.service[env].project_id }
}

# Enable required APIs
resource "google_project_service" "run" {
  for_each = local.projects

  project            = each.value
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Create service accounts
resource "google_service_account" "hello-app" {
  for_each = local.projects

  project      = each.value
  account_id   = "hello-app"
  display_name = "hello-app"
  description  = "Service Account for app in ${each.key} environment"
}

# Deploy Cloud Run service
resource "google_cloud_run_v2_service" "hello-app" {
  for_each = local.projects

  project  = each.value
  location = var.region
  name     = "hello-app"

  template {
    service_account = google_service_account.hello-app[each.key].email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
    }
  }

  ingress = "INGRESS_TRAFFIC_ALL"

  invoker_iam_disabled = true

  # TODO
  deletion_protection = false
  depends_on          = [google_project_service.run]

  lifecycle {
    ignore_changes = [template]
  }
}
