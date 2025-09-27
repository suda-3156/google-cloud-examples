output "hello-app-urls" {
  value       = { for env in local.envs : env => google_cloud_run_v2_service.hello-app[env].uri }
  description = "The URL of the hello-app service in each environment"
}
