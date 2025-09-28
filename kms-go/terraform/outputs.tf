output "api-service-url" {
  value       = google_cloud_run_v2_service.api.uri
  description = "The URL of the API service"
}
