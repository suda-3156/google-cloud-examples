/* GCKMS is an interface for Google Cloud Key Management Service.
 * References:
 *   https://cloud.google.com/kms/docs/reference/libraries?hl=ja#client-libraries-install-go
 *
 * NOTE:
 *  - `connStr` should be in the format of:
 *    `projects/{project_id}/locations/{location_id}/keyRings/{key_ring_name}/cryptoKeys/{key_name}`
 *    `projects/{project_id}/locations/{location_id}/keyRings/{key_ring_name}/cryptoKeys/{key_name}/cryptoKeyVersions/1`
 *
 */

package gckms

import (
	"context"

	kms "cloud.google.com/go/kms/apiv1"
)

type gckms struct {
	client *kms.KeyManagementClient
}

type GCKMS interface {
	ListKeyRings(ctx context.Context, projectID, locationID string) ([]string, error)
	ListKeys(ctx context.Context, projectID, locationID, keyRingName string) ([]string, error)
	EncryptSymmetric(ctx context.Context, connStr string, plaintext string) ([]byte, error)
	DecryptSymmetric(ctx context.Context, connStr string, ciphertext []byte) (string, error)
	EncryptAsymmetric(ctx context.Context, connStr string, plaintext string) ([]byte, error)
	DecryptAsymmetric(ctx context.Context, connStr string, ciphertext []byte) (string, error)
	SignAsymmetric(ctx context.Context, connStr string, message string) ([]byte, error)
	VerifyAsymmetricEC(ctx context.Context, connStr string, message, signature []byte) (bool, error)
	VerifyAsymmetricRSA(ctx context.Context, connStr string, message, signature []byte) (bool, error)
}

func New(client *kms.KeyManagementClient) GCKMS {
	return &gckms{
		client: client,
	}
}
