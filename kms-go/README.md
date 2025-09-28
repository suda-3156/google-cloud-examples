# Cloud KMS go example

This is simply an adjusted version of the [official sample code](https://cloud.google.com/kms/docs/use-keys-google-cloud) to make it usable by copy-pasting.

## curl

Example of params

- `LOCATION_ID=global`
- `KEY_RING_NAME=key-ring-1`
- `KEY_NAME=key-1-symmetric-key`

```sh
# list key rings
curl -X GET "${CLOUD_RUN_URL}/list_key_rings?project_id=${PROJECT_ID}&location_id=${LOCATION_ID}"

# list keys of a key ring
curl -X GET "${CLOUD_RUN_URL}/list_keys?project_id=${PROJECT_ID}&location_id=${LOCATION_ID}&key_ring_name=${KEY_RING_NAME}"

# encrypt
curl -X POST ${CLOUD_RUN_URL}/encrypt \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}",
    "plaintext": "Hello, World!"
  }'

# decrypt
curl -X POST ${CLOUD_RUN_URL}/decrypt \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}",
    "ciphertext": "<The ciphertext value obtained from the encrypt API>"
  }'

# encrypt asymmetric
curl -X POST ${CLOUD_RUN_URL}/encrypt_asymmetric \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}", // e.g. ${var.key_name_prefix}-asymmetric-decrypt-key
    "plaintext": "Hello, World!"
  }'

# decrypt asymmetric
curl -X POST ${CLOUD_RUN_URL}/decrypt_asymmetric \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}", // e.g. ${var.key_name_prefix}-asymmetric-decrypt-key
    "ciphertext": "<The ciphertext value obtained from the encrypt API>"
  }'

# sign asymmetric
curl -X POST ${CLOUD_RUN_URL}/sign_asymmetric \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}",
    "message": "Hello, World!"
  }'

# verify asymmetric
curl -X POST ${CLOUD_RUN_URL}/verify_asymmetric \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "${PROJECT_ID}",
    "location_id": "${LOCATION_ID}",
    "key_ring_name": "${KEY_RING_NAME}",
    "key_name": "${KEY_NAME}",
    "message": "Hello, World!",
    "signature: "<The signature value obtained from the sign API>"
  }'
```
