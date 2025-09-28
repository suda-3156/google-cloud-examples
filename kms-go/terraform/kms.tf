resource "google_project_service" "kms" {
  project            = "${var.project_id_prefix}-service"
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false

  depends_on = [time_sleep.wait_for_project]
}

# To allow encrypt/decrypt operations:
# permission: cloudkms.cryptoKeyVersions.useToEncrypt, cloudkms.cryptoKeyVersions.useToDecrypt
resource "google_project_iam_member" "kms" {
  project = "${var.project_id_prefix}-service"
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# To allow listing key rings and keys:
resource "google_project_iam_member" "list_keyrings" {
  project = "${var.project_id_prefix}-service"
  role    = "roles/cloudkms.viewer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# To allow obtaining public key for asymmetric decrypt key (permission: cloudkms.cryptoKeyVersions.viewPublicKey):
resource "google_project_iam_member" "get_public_key" {
  project = "${var.project_id_prefix}-service"
  role    = "roles/cloudkms.publicKeyViewer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# To allow decrypting with asymmetric decrypt key (permission: cloudkms.cryptoKeyVersions.useToDecrypt):
# roles/cloudkms.cryptoKeyDecrypter
# or roles/cloudkms.cryptoKeyEncrypterDecrypter ...

# To allow signing with asymmetric sign key (permission: cloudkms.cryptoKeyVersions.useToSign):
resource "google_project_iam_member" "sign_asymmetric" {
  project = "${var.project_id_prefix}-service"
  role    = "roles/cloudkms.signer" # or roles/cloudkms.signerVerifier
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_kms_key_ring" "main" {
  name     = var.key_ring_name
  project  = "${var.project_id_prefix}-service"
  location = "global"

  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "symmetric_key" {
  name     = "${var.key_name_prefix}-symmetric-key"
  purpose  = "ENCRYPT_DECRYPT"
  key_ring = google_kms_key_ring.main.id
}

# CryptoKey Version Algorithm Reference:
# https://cloud.google.com/kms/docs/reference/rest/v1/CryptoKeyVersionAlgorithm
resource "google_kms_crypto_key" "asymmetric_decrypt_key" {
  name     = "${var.key_name_prefix}-asymmetric-decrypt-key"
  purpose  = "ASYMMETRIC_DECRYPT"
  key_ring = google_kms_key_ring.main.id

  version_template {
    algorithm = "RSA_DECRYPT_OAEP_2048_SHA256"
  }
}

resource "google_kms_crypto_key" "asymmetric_sign_key" {
  name     = "${var.key_name_prefix}-asymmetric-sign-key"
  purpose  = "ASYMMETRIC_SIGN"
  key_ring = google_kms_key_ring.main.id

  version_template {
    algorithm = "RSA_SIGN_PSS_2048_SHA256"
  }
}
