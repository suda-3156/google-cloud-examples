# Pipeline

// ---------- project ---------- //
resource "google_project" "pipeline" {
  name            = "${var.project_id_prefix}-pipeline"
  project_id      = "${var.project_id_prefix}-pipeline"
  billing_account = data.google_billing_account.billing.id
  folder_id       = var.folder_id

  # TODO
  deletion_policy = "DELETE"
}

# Timeout
resource "time_sleep" "wait_for_pipeline_project_creation" {
  depends_on      = [google_project.pipeline]
  create_duration = "60s"
}

# apis
resource "google_project_service" "artifactregistry" {
  project = google_project.pipeline.project_id
  service = "artifactregistry.googleapis.com"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

resource "google_project_service" "clouddeploy" {
  project = google_project.pipeline.project_id
  service = "clouddeploy.googleapis.com"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

// ---------- service account ---------- //
# create release and rollout for dev target
resource "google_service_account" "releaser" {
  project = google_project.pipeline.project_id

  account_id   = "releaser"
  display_name = "Releaser"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

# promote to stg target
resource "google_service_account" "stg-promoter" {
  project = google_project.pipeline.project_id

  account_id   = "stg-promoter"
  display_name = "Stg Promoter"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

# promote to prod target
resource "google_service_account" "prod-promoter" {
  project = google_project.pipeline.project_id

  account_id   = "prod-promoter"
  display_name = "Prod Promoter"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

# deploy target
resource "google_service_account" "deploy-target" {
  for_each = local.projects

  project = google_project.pipeline.project_id

  account_id   = "deploy-target-${each.key}"
  display_name = "Deploy Target ${each.key}"

  depends_on = [time_sleep.wait_for_pipeline_project_creation]
}

// ---------- storage ---------- //
# storage for arfifacts and app source
resource "google_storage_bucket" "storage" {
  name     = "${var.project_id_prefix}-pipeline-storage"
  location = var.region
  project  = google_project.pipeline.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 10
    }
  }

  # TODO
  force_destroy = true
}

// ---------- artifact registory ---------- //
# artifact registory for container image
resource "google_artifact_registry_repository" "repository" {
  repository_id = "pipeline-repo"
  location      = var.region
  format        = "DOCKER"

  project = google_project.pipeline.project_id

  depends_on = [google_project_service.artifactregistry]
}

// ---------- cloud deploy ---------- //
# deploy target
resource "google_clouddeploy_target" "app" {
  for_each = local.projects

  project     = google_project.pipeline.project_id
  location    = var.region
  name        = "${each.key}-target"
  description = "Cloud Deploy Target for ${each.key}"

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = google_service_account.deploy-target[each.key].email
    artifact_storage = "gs://${google_storage_bucket.storage.name}/artifacts"
  }

  run {
    location = "projects/${each.value}/locations/${var.region}"
  }

  deploy_parameters = {
    message              = "Hello from ${each.key}!"
    service_account_name = google_service_account.run[each.key].email
  }
}

# pipeline
resource "google_clouddeploy_delivery_pipeline" "app" {
  project     = google_project.pipeline.project_id
  location    = var.region
  name        = "app-pipeline"
  description = "Cloud Deploy Pipeline for deploying to dev, stg, and prod targets in serial"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.app["dev"].name
    }
    stages {
      target_id = google_clouddeploy_target.app["stg"].name
    }
    stages {
      target_id = google_clouddeploy_target.app["prod"].name
    }
  }
}
