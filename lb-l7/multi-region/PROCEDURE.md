# Procedure

## Preparation

```sh
gcloud config configurations list
gcloud config configurations activate [config-name]
gcloud auth application-default login

gcloud projects create ${PROJECT_ID_PREFIX}-tf --folder ${FOLDER_ID}
gcloud projects describe ${PROJECT_ID_PREFIX}-tf
gcloud config set project ${PROJECT_ID_PREFIX}-tf

# Link the billing account
gcloud billing projects link ${PROJECT_ID_PREFIX}-tf --billing-account=${BILLING_ACCOUNT_ID}

gcloud auth application-default set-quota-project ${PROJECT_ID_PREFIX}-tf
```

## Initialize

```sh
cd terraform
terraform init
terraform apply
```

Add an A record with the reserved IP address and your chosen domain.

## Verification

It may take up to 60 minutes for the domain to become active.
For more details, refer to [Troubleshooting SSL certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/troubleshooting).

```sh
# List certificates
gcloud compute ssl-certificates list --project ${PROJECT_ID_PREFIX}-service

# Describe certificate status
gcloud compute ssl-certificates describe lb-ssl-cert \
   --global \
   --format="get(name,managed.status, managed.domainStatus)" \
   --project ${PROJECT_ID_PREFIX}-service
```

## Cleanup

```sh
cd terraform
terraform destroy
gcloud projects delete ${PROJECT_ID_PREFIX}-tf
```

## Optional

To reserve a global static IP address using `gcloud`:

```sh
gcloud compute addresses create lb-static-ip \
  --network-tier=PREMIUM \
  --ip-version=IPV4 \
  --global \
  --project ${PROJECT_ID_PREFIX}-service

# To delete the address:
gcloud compute addresses delete lb-static-ip \
  --global \
  --project ${PROJECT_ID_PREFIX}-service
```

## For SSH to confirm `ROUND_ROBIN` load balancing

### Initialize

```sh
cd vm
terraform init
terraform apply
```

### Connect

```sh
gcloud compute ssh INSTANCE_NAME --zone ZONE --project PROJECT_ID
# Example:
gcloud compute ssh vm-asia-northeast1 --zone asia-northeast1-a --project ${PROJECT_ID_PREFIX}-vm

# Then:
curl https://<your-domain.com> # You should see region information in the HTML response.
```

### Cleanup

```sh
cd vm
terraform destroy
```
