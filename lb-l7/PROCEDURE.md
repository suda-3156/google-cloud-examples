# Procedure

## Preparation

```sh
gcloud config configurations list
gcloud config configurations activate [config-name]
gcloud auth application-default login

gcloud projects create ${PROJECT_ID_PREFIX}-tf --folder ${FOLDER_ID}
gcloud projects describe ${PROJECT_ID_PREFIX}-tf
gcloud config set project ${PROJECT_ID_PREFIX}-tf

# bind billing account
gcloud billing projects link ${PROJECT_ID_PREFIX}-tf --billing-account=${BILLING_ACCOUNT_ID}

gcloud auth application-default set-quota-project ${PROJECT_ID_PREFIX}-tf
```

## Initialize

```sh
terraform init
terraform apply
```

You need to add an A record with the reserved IP address and your selected domain.

## Verification

It may take up to 60 minutes for the domain to become active.
For more information, see [Troubleshooting SSL certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/troubleshooting).

```sh
# list certificates
gcloud compute ssl-certificates list --project ${PROJECT_ID_PREFIX}-service

# describe certificate status
gcloud compute ssl-certificates describe ${PROJECT_ID_PREFIX}-lb-ssl-cert \
   --global \
   --format="get(name,managed.status, managed.domainStatus)" \
   --project ${PROJECT_ID_PREFIX}-service
```

## Cleanup

```sh
terraform destroy
gcloud projects delete ${PROJECT_ID_PREFIX}-tf
```

## Optional

To reserve a global static IP address using `gcloud`:

```sh
gcloud compute addresses create ${PROJECT_ID_PREFIX}-lb-ip \
  --network-tier=PREMIUM \
  --ip-version=IPV4 \
  --global \
  --project ${PROJECT_ID_PREFIX}-service

# To delete the address:
gcloud compute addresses delete ${PROJECT_ID_PREFIX}-lb-ip \
  --global \
  --project ${PROJECT_ID_PREFIX}-service
```
