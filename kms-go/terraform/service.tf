resource "google_project" "service" {
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
  depends_on      = [google_project.service]
}

# Enable required APIs
resource "google_project_service" "run" {
  project            = "${var.project_id_prefix}-service"
  service            = "run.googleapis.com"
  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_project]
}

resource "google_project_service" "artifactregistry" {
  project            = "${var.project_id_prefix}-service"
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_project]
}

# Create service accounts
resource "google_service_account" "api" {
  project      = "${var.project_id_prefix}-service"
  account_id   = "run-api"
  display_name = "Run API Service Account"
  description  = "Service Account for Cloud Run api"

  depends_on = [google_project_service.run]
}

# Deploy Cloud Run service
resource "google_cloud_run_v2_service" "api" {
  project  = "${var.project_id_prefix}-service"
  location = var.region
  name     = "api"

  template {
    service_account = google_service_account.api.email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
    }
  }

  ingress = "INGRESS_TRAFFIC_ALL"

  invoker_iam_disabled = true

  # TODO
  deletion_protection = false

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
  
  depends_on          = [google_service_account.api]
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "repo" {
  project       = "${var.project_id_prefix}-service"
  location      = var.region
  repository_id = "api-repo"
  description   = "Artifact Registry for API container images"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}
