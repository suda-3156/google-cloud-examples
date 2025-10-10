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
  name    = "${var.project_id_prefix}-lb-ip"
  project = google_project.main.project_id

  depends_on = [google_project_service.apis_for_lb]
}

# SSL
resource "google_compute_managed_ssl_certificate" "main" {
  name    = "${var.project_id_prefix}-lb-ssl-cert"
  project = google_project.main.project_id

  managed {
    domains = var.lb_ssl_domains
  }

  depends_on = [google_project_service.apis_for_lb]
}

resource "google_compute_ssl_policy" "main" {
  name    = "${var.project_id_prefix}-lb-ssl-policy"
  project = google_project.main.project_id

  profile         = "MODERN"
  min_tls_version = "TLS_1_2"

  depends_on = [google_project_service.apis_for_lb]
}

resource "google_compute_security_policy" "main" {
  name    = "${var.project_id_prefix}-lb-security-policy"
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
  for_each = toset(local.run_suffix)

  name                  = "${var.project_id_prefix}-neg-${each.key}"
  project               = google_project.main.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.main[each.key].name
  }

  depends_on = [google_cloud_run_v2_service.main, google_project_service.apis_for_lb]
}

# Backend Service
resource "google_compute_backend_service" "main" {
  name    = "${var.project_id_prefix}-lb-backend-main"
  project = google_project.main.project_id

  backend {
    group = google_compute_region_network_endpoint_group.main["a"].id
  }

  connection_draining_timeout_sec = 0
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  protocol                        = "HTTP"
  port_name                       = "http"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  enable_cdn                      = false

  security_policy = google_compute_security_policy.main.id
}

resource "google_compute_backend_service" "only-b" {
  name    = "${var.project_id_prefix}-lb-backend-only-b"
  project = google_project.main.project_id

  backend {
    group = google_compute_region_network_endpoint_group.main["b"].id
  }

  connection_draining_timeout_sec = 0
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  protocol                        = "HTTP"
  port_name                       = "http"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  enable_cdn                      = false

  security_policy = google_compute_security_policy.main.id
}

resource "google_compute_backend_service" "only-c" {
  name    = "${var.project_id_prefix}-lb-backend-only-c"
  project = google_project.main.project_id

  backend {
    group = google_compute_region_network_endpoint_group.main["c"].id
  }

  connection_draining_timeout_sec = 0
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  protocol                        = "HTTP"
  port_name                       = "http"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  enable_cdn                      = false

  security_policy = google_compute_security_policy.main.id
}

# URL Map
resource "google_compute_url_map" "main" {
  name    = "${var.project_id_prefix}-lb-url-map"
  project = google_project.main.project_id

  default_service = google_compute_backend_service.main.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name = "allpaths"
    # default_service = google_compute_backend_service.main.self_link

    path_rule {
      paths   = ["/c"]
      service = google_compute_backend_service.only-c.self_link
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
    }

    default_route_action {
      weighted_backend_services {
        backend_service = google_compute_backend_service.main.self_link
        weight          = 50
      }
      weighted_backend_services {
        backend_service = google_compute_backend_service.only-b.self_link
        weight          = 50
      }
    }
  }
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
