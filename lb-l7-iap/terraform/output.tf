output "lb_ip_address" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "cloud_run_service_uri" {
  description = "The URI of the Cloud Run service, You cannot access them directly, you need to go through the load balancer."
  value       = google_cloud_run_v2_service.main.uri
}
