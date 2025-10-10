locals {
  envs = ["dev", "stg", "prod"]
}

resource "google_project" "service" {
  for_each = { for env in local.envs : env => "${var.project_id_prefix}-${env}" }

  name            = each.value
  project_id      = each.value
  folder_id       = var.folder_id
  billing_account = var.billing_account_id

  # TODO
  deletion_policy = "DELETE"
}

locals {
  projects = { for env in local.envs : env => google_project.service[env].project_id }
}

# Timeout
resource "time_sleep" "wait_for_project_creation" {
  depends_on      = [google_project.service]
  create_duration = "60s"
}

resource "google_project_service" "run" {
  for_each = local.projects

  project = each.value
  service = "run.googleapis.com"

  depends_on = [time_sleep.wait_for_project_creation]
}

resource "google_service_account" "run" {
  for_each = local.projects

  account_id   = "run-sa"
  display_name = "Cloud Run Service Account for ${each.key} environment"
  project      = each.value

  depends_on = [google_project_service.run]
}

resource "google_cloud_run_v2_service" "app" {
  for_each = local.projects

  name    = "app"
  project = each.value

  location = var.region

  template {
    service_account = google_service_account.run[each.key].email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true

  # TODO
  deletion_protection = false

  depends_on = [google_project_service.run]
  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
}
