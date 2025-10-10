# Required apis
locals {
  apis_for_lb = [
    "compute.googleapis.com",
  ]
}

resource "google_project_service" "apis_for_lb" {
  for_each = toset(local.apis_for_lb)

  project = google_project.main.project_id
  service = each.key

  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_project]
}

# static IP
resource "google_compute_global_address" "main" {
  name    = "lb-static-ip"
  project = google_project.main.project_id

  depends_on = [google_project_service.apis_for_lb]
}

# SSL
resource "google_compute_managed_ssl_certificate" "main" {
  name    = "lb-ssl-cert"
  project = google_project.main.project_id

  managed {
    domains = var.lb_ssl_domains
  }

  depends_on = [google_project_service.apis_for_lb]
}

resource "google_compute_ssl_policy" "main" {
  name    = "lb-ssl-policy"
  project = google_project.main.project_id

  profile         = "MODERN"
  min_tls_version = "TLS_1_2"

  depends_on = [google_project_service.apis_for_lb]
}

resource "google_compute_security_policy" "main" {
  name    = "lb-security-policy"
  project = google_project.main.project_id

  adaptive_protection_config {
    # DDOS
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }

  rule {
    action   = "allow"
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [google_project_service.apis_for_lb]
}

# NEG
resource "google_compute_region_network_endpoint_group" "main" {
  for_each = toset(var.regions)

  name                  = "run-app-neg-${each.key}"
  project               = google_project.main.project_id
  region                = each.key
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.app[each.key].name
  }

  depends_on = [google_cloud_run_v2_service.app, google_project_service.apis_for_lb]
}

# Backend Service - Single service with multiple regional backends
resource "google_compute_backend_service" "main" {
  name    = "lb-backend-main"
  project = google_project.main.project_id

  # Add all regional NEGs as backends
  dynamic "backend" {
    for_each = toset(var.regions)
    content {
      group = google_compute_region_network_endpoint_group.main[backend.key].id
    }
  }

  connection_draining_timeout_sec = 0
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  protocol                        = "HTTP"
  port_name                       = "http"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  enable_cdn                      = false

  # Enable automatic geographic routing based on client location
  locality_lb_policy = "ROUND_ROBIN"

  security_policy = google_compute_security_policy.main.id

  depends_on = [google_project_service.apis_for_lb]
}

# URL Map
resource "google_compute_url_map" "main" {
  name    = "${var.project_id_prefix}-lb-url-map"
  project = google_project.main.project_id

  default_service = google_compute_backend_service.main.id

  depends_on = [google_project_service.apis_for_lb]
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "main" {
  name    = "${var.project_id_prefix}-lb-https-proxy"
  project = google_project.main.project_id

  ssl_certificates = [google_compute_managed_ssl_certificate.main.id]
  ssl_policy       = google_compute_ssl_policy.main.name
  url_map          = google_compute_url_map.main.id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "main" {
  name    = "${var.project_id_prefix}-lb-https-forwarding-rule"
  project = google_project.main.project_id

  ip_protocol           = "TCP"
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.main.id
  ip_address            = google_compute_global_address.main.id
}

# Redirect HTTP to HTTPS
resource "google_compute_url_map" "redirect" {
  name    = "${var.project_id_prefix}-http-to-https-redirect"
  project = google_project.main.project_id

  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }

  depends_on = [google_project_service.apis_for_lb]
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.project_id_prefix}-http-lb-proxy"
  project = google_project.main.project_id

  url_map = google_compute_url_map.redirect.self_link
}

resource "google_compute_global_forwarding_rule" "redirect" {
  name    = "${var.project_id_prefix}-http-redirect-rule"
  project = google_project.main.project_id

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.self_link
  ip_address            = google_compute_global_address.main.id
}
