output "lb_ip_address" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "cloud_run_service_uris" {
  description = "The URIs of the Cloud Run services, You cannot access them directly, you need to go through the load balancer."
  value = {
    for k, v in google_cloud_run_v2_service.app :
    k => google_cloud_run_v2_service.app[k].uri
  }
}
