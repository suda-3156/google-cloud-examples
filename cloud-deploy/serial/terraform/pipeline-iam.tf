// ---------- releaser ---------- //
# bucket access for releaser
locals {
  releaser_storage_roles = [
    "roles/storage.objectCreator",
    "roles/storage.legacyBucketReader"
  ]
}

resource "google_storage_bucket_iam_member" "releaser" {
  for_each = toset(local.releaser_storage_roles)

  bucket = google_storage_bucket.storage.name
  role   = each.value
  member = "serviceAccount:${google_service_account.releaser.email}"
}

# artifact registry access for releaser
resource "google_artifact_registry_repository_iam_member" "releaser" {
  project = google_artifact_registry_repository.repository.project

  repository = google_artifact_registry_repository.repository.name
  location   = google_artifact_registry_repository.repository.location
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.releaser.email}"
}

# releaser as deploy target executor
resource "google_service_account_iam_member" "releaser-as-deploy-target" {
  for_each = local.projects

  service_account_id = google_service_account.deploy-target[each.key].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.releaser.email}"
}

# cloud deploy viewer
resource "google_project_iam_member" "releaser-clouddeploy-viewer" {
  for_each = local.rollout_creators

  project = google_project.pipeline.project_id
  role    = "roles/clouddeploy.viewer"
  member  = each.value
}

// ---------- promoters ---------- //
# promoters as deploy target executor
resource "google_service_account_iam_member" "stg-promoter-as-deploy-target" {
  service_account_id = google_service_account.deploy-target["stg"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.stg-promoter.email}"
}

resource "google_service_account_iam_member" "prod-promoter-as-deploy-target" {
  service_account_id = google_service_account.deploy-target["prod"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.prod-promoter.email}"
}

// ---------- deploy target ---------- //
# deploy target access to artifact registry
resource "google_artifact_registry_repository_iam_member" "deploy-target" {
  for_each = local.projects

  project    = google_artifact_registry_repository.repository.project
  location   = google_artifact_registry_repository.repository.location
  repository = google_artifact_registry_repository.repository.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

# logging from cloud build
resource "google_project_iam_member" "deploy-target" {
  for_each = local.projects

  project = google_project.pipeline.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

# access to storage bucket for deploy target
resource "google_storage_bucket_iam_member" "deploy-target-objectViewer" {
  for_each = local.projects

  bucket = google_storage_bucket.storage.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

resource "google_storage_bucket_iam_member" "deploy-target-objectCreator" {
  for_each = local.projects

  bucket = google_storage_bucket.storage.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

# cloud run access for deploy target
resource "google_service_account_iam_member" "deploy-target-as-app" {
  for_each = local.projects

  service_account_id = google_service_account.run[each.key].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

resource "google_cloud_run_v2_service_iam_member" "deploy-target-run-invoker" {
  for_each = local.projects

  project  = google_cloud_run_v2_service.app[each.key].project
  location = google_cloud_run_v2_service.app[each.key].location
  name     = google_cloud_run_v2_service.app[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

resource "google_project_iam_member" "deploy-target-run-developer" {
  for_each = local.projects

  project = each.value
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.deploy-target[each.key].email}"
}

// ---------- custom role ---------- //
resource "google_project_iam_custom_role" "clouddeploy-releaser" {
  project     = google_project.pipeline.project_id
  role_id     = "ClouddeployReleaseCreator"
  title       = "Cloud Deploy Release Creator"
  permissions = ["clouddeploy.releases.create"]
}

data "google_iam_policy" "app" {
  binding {
    role    = google_project_iam_custom_role.clouddeploy-releaser.id
    members = ["serviceAccount:${google_service_account.releaser.email}"]
  }

  binding {
    role    = "roles/clouddeploy.releaser"
    members = ["serviceAccount:${google_service_account.releaser.email}"]
    condition {
      title      = "Rollout to dev"
      expression = "api.getAttribute(\"clouddeploy.googleapis.com/rolloutTarget\", \"\") == \"${google_clouddeploy_target.app["dev"].name}\""
    }
  }

  binding {
    role    = "roles/clouddeploy.releaser"
    members = ["serviceAccount:${google_service_account.stg-promoter.email}"]
    condition {
      title      = "Rollout to stg"
      expression = "api.getAttribute(\"clouddeploy.googleapis.com/rolloutTarget\", \"\") == \"${google_clouddeploy_target.app["stg"].name}\""
    }
  }

  binding {
    role    = "roles/clouddeploy.releaser"
    members = ["serviceAccount:${google_service_account.prod-promoter.email}"]
    condition {
      title      = "Rollout to prod"
      expression = "api.getAttribute(\"clouddeploy.googleapis.com/rolloutTarget\", \"\") == \"${google_clouddeploy_target.app["prod"].name}\""
    }
  }
}

resource "google_clouddeploy_delivery_pipeline_iam_policy" "app" {
  project     = google_clouddeploy_delivery_pipeline.app.project
  location    = google_clouddeploy_delivery_pipeline.app.location
  name        = google_clouddeploy_delivery_pipeline.app.name
  policy_data = data.google_iam_policy.app.policy_data
}

locals {
  rollout_creators = {
    releaser      = "serviceAccount:${google_service_account.releaser.email}"
    stg_promoter  = "serviceAccount:${google_service_account.stg-promoter.email}"
    prod_promoter = "serviceAccount:${google_service_account.prod-promoter.email}"
  }
}

// ---------- service agent ---------- //
# Reference: https://cloud.google.com/run/docs/deploying#other-projects
resource "google_artifact_registry_repository_iam_member" "service-agent" {
  for_each = local.projects

  project    = google_artifact_registry_repository.repository.project
  location   = google_artifact_registry_repository.repository.location
  repository = google_artifact_registry_repository.repository.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${google_project.service[each.key].number}@serverless-robot-prod.iam.gserviceaccount.com"
}
