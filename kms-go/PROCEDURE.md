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

## Init

```sh
terraform init
terraform apply
```

## Build and Deploy

```sh
gcloud artifacts repositories list \
--project=${PROJECT_ID_PREFIX}-service

gcloud auth configure-docker ${REGION}-docker.pkg.dev

task release
```

## Destroy

```sh
terraform destroy
gcloud projects delete ${PROJECT_ID_PREFIX}-tf
```
