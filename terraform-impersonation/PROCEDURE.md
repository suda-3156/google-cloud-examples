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

# api
# For impersonation?
gcloud services enable iamcredentials.googleapis.com --project ${PROJECT_ID_PREFIX}-tf
# For binding billing accounts
gcloud services enable cloudbilling.googleapis.com --project ${PROJECT_ID_PREFIX}-tf
# For creating projects
gcloud services enable cloudresourcemanager.googleapis.com --project ${PROJECT_ID_PREFIX}-tf
# For creating service accounts
gcloud services enable iam.googleapis.com --project ${PROJECT_ID_PREFIX}-tf

# terraform sa
gcloud iam service-accounts create ${TF_EXEC_SA} \
--display-name="terraform" \
--project=${PROJECT_ID_PREFIX}-tf

gcloud iam service-accounts add-iam-policy-binding ${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com \
--member="user:${USER_EMAIL}" \
--role="roles/iam.serviceAccountTokenCreator" \
--project=${PROJECT_ID_PREFIX}-tf

gcloud projects add-iam-policy-binding ${PROJECT_ID_PREFIX}-tf \
--member="user:${USER_EMAIL}" \
--role="roles/serviceusage.serviceUsageConsumer"

# terraform bucket
gcloud storage buckets create gs://${PROJECT_ID_PREFIX}-tf-main \
--default-storage-class=standard \
--location=${REGION} \
--uniform-bucket-level-access \
--project=${PROJECT_ID_PREFIX}-tf

gcloud storage buckets update gs://${PROJECT_ID_PREFIX}-tf-main --versioning

# terraform saのロール
# プロジェクト作成権限
gcloud resource-manager folders add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/resourcemanager.projectCreator"
# Service Account に Storage バケットへのアクセス権限を付与
gcloud storage buckets add-iam-policy-binding gs://${PROJECT_ID_PREFIX}-tf-main \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/storage.admin"
# sa
gcloud resource-manager folders add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/iam.serviceAccountUser"
# sa作成
gcloud resource-manager folders add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/iam.serviceAccountAdmin"
# iam
gcloud resource-manager folders add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/resourcemanager.folderIamAdmin"
# billing
gcloud billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/billing.user"
gcloud billing accounts add-iam-policy-binding ${BILLING_ACCOUNT_ID} \
--member="serviceAccount:${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com" \
--role="roles/billing.viewer"
```

## Init

```sh
# 上で指定したユーザーに変更
gcloud config configurations activate [config-name]

# terraform実行時の課金先を ${PROJECT_ID_PREFIX}-tf に設定
gcloud auth application-default login
gcloud auth application-default set-quota-project ${PROJECT_ID_PREFIX}-tf

# terraform init
terraform init \
-backend-config="bucket=${PROJECT_ID_PREFIX}-tf-main" \
-backend-config="impersonate_service_account=${TF_EXEC_SA}@${PROJECT_ID_PREFIX}-tf.iam.gserviceaccount.com"
```

## Destroy

```sh
terraform destroy
gcloud config configurations activate [config-name]
gcloud projects delete ${PROJECT_ID_PREFIX}-tf
```
