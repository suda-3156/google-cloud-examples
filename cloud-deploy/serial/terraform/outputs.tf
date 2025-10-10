output "rollout_creators" {
  description = "The service accounts that can create rollouts."
  value       = local.rollout_creators
}

output "cloud_run_uris" {
  description = "The Cloud Run service URIs."
  value = {
    for k, v in google_cloud_run_v2_service.app : k => v.uri
  }
}

output "artifact_registry_repo" {
  description = "The Artifact Registry repository."
  value       = google_artifact_registry_repository.repository.id
}

output "deploy_pipeline" {
  description = "The Cloud Deploy pipeline name."
  value       = google_clouddeploy_delivery_pipeline.app.name
}

output "storage" {
  description = "The GCS bucket name."
  value       = google_storage_bucket.storage.name
}
