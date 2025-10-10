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

### Impersonation

```sh
gcloud iam service-accounts add-iam-policy-binding "projects/${PROJECT_ID_PREFIX}-pipeline/serviceAccounts/${PROJECT_ID_PREFIX}-pipeline-releaser@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com" \
  --member "user:$(gcloud config get account)" \
  --role roles/iam.serviceAccountTokenCreator
gcloud iam service-accounts add-iam-policy-binding "projects/${PROJECT_ID_PREFIX}-pipeline/serviceAccounts/${PROJECT_ID_PREFIX}-stg-promoter@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com" \
  --member "user:$(gcloud config get account)" \
  --role roles/iam.serviceAccountTokenCreator
gcloud iam service-accounts add-iam-policy-binding "projects/${PROJECT_ID_PREFIX}-pipeline/serviceAccounts/${PROJECT_ID_PREFIX}-prod-promoter@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com" \
  --member "user:$(gcloud config get account)" \
  --role roles/iam.serviceAccountTokenCreator
```

## Deploy

### Build

```sh
cd deploy
gcloud config set project ${PROJECT_ID_PREFIX}-pipeline
export APP_VERSION=v1.0.1
gcloud config set auth/impersonate_service_account "${PROJECT_ID_PREFIX}-pipeline-releaser@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com"
skaffold build \
  --filename skaffold.yaml \
  --default-repo "${REGION}-docker.pkg.dev/${PROJECT_ID_PREFIX}-pipeline/${PROJECT_ID_PREFIX}-pipeline-repo" \
  --file-output artifacts.json
gcloud config unset auth/impersonate_service_account
```

### Deploy to dev

```sh
gcloud config set project "{{.PROJECT_ID_PREFIX}}-pipeline"
export RELEASE_NAME="v1-0-0"
gcloud deploy releases create ${RELEASE_NAME} \
  --region="asia-northeast1" \
  --delivery-pipeline="app-pipeline" \
  --gcs-source-staging-dir "gs://${PROJECT_ID_PREFIX}-pipeline-storage/app/source" \
  --build-artifacts artifacts.json \
  --skaffold-file skaffold.yaml \
  --enable-initial-rollout \
  --impersonate-service-account "releaser@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com"
```

### Promote to stg

```sh
gcloud config set project "{{.PROJECT_ID_PREFIX}}-pipeline"
export RELEASE_NAME="v1-0-0"
gcloud deploy releases promote \
  --release ${RELEASE_NAME} \
  --delivery-pipeline app-pipeline \
  --region ${REGION} \
  --impersonate-service-account "stg-promoter@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com"
```

### Promote to prod

```sh
gcloud config set project "{{.PROJECT_ID_PREFIX}}-pipeline"
export RELEASE_NAME="v1-0-0"
gcloud deploy releases promote \
  --release ${RELEASE_NAME} \
  --delivery-pipeline app-pipeline \
  --region ${REGION} \
  --impersonate-service-account "prod-promoter@${PROJECT_ID_PREFIX}-pipeline.iam.gserviceaccount.com"
```

## Cleanup

```sh
terraform destroy
gcloud projects delete ${PROJECT_ID_PREFIX}-tf
```
