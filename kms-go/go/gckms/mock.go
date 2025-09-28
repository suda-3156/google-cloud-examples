package gckms

import (
	"context"
	"fmt"

	kms "cloud.google.com/go/kms/apiv1"
)

func NewMock(client *kms.KeyManagementClient) GCKMS {
	return &mock{
		client: client,
	}
}

type mock struct {
	client *kms.KeyManagementClient
}

func (m *mock) ListKeyRings(ctx context.Context, projectID, locationID string) ([]string, error) {
	return []string{
		"projects/mock-project/locations/mock-location/keyRings/key-ring-1",
		"projects/mock-project/locations/mock-location/keyRings/key-ring-2",
	}, nil
}

func (m *mock) ListKeys(ctx context.Context, projectID, locationID, keyRingName string) ([]string, error) {
	return []string{
		"projects/mock-project/locations/mock-location/keyRings/" + keyRingName + "/cryptoKeys/key-1",
		"projects/mock-project/locations/mock-location/keyRings/" + keyRingName + "/cryptoKeys/key-2",
	}, nil
}

func (m *mock) EncryptSymmetric(ctx context.Context, connStr string, plaintext string) ([]byte, error) {
	mockCiphertext := "encrypted:" + plaintext
	return []byte(mockCiphertext), nil
}

func (m *mock) DecryptSymmetric(ctx context.Context, connStr string, ciphertext []byte) (string, error) {
	ciphertextStr := string(ciphertext)
	if len(ciphertextStr) > 10 && ciphertextStr[:10] == "encrypted:" {
		return ciphertextStr[10:], nil
	}

	return "", fmt.Errorf("invalid ciphertext format")
}

func (m *mock) EncryptAsymmetric(ctx context.Context, connStr string, plaintext string) ([]byte, error) {
	mockCiphertext := "asymmetric-encrypted:" + plaintext
	return []byte(mockCiphertext), nil
}

func (m *mock) DecryptAsymmetric(ctx context.Context, connStr string, ciphertext []byte) (string, error) {
	ciphertextStr := string(ciphertext)
	prefix := "asymmetric-encrypted:"
	if len(ciphertextStr) > len(prefix) && ciphertextStr[:len(prefix)] == prefix {
		return ciphertextStr[len(prefix):], nil
	}

	return "", fmt.Errorf("invalid asymmetric ciphertext format")
}

func (m *mock) SignAsymmetric(ctx context.Context, connStr string, message string) ([]byte, error) {
	mockSignature := "signed:" + message
	return []byte(mockSignature), nil
}

func (m *mock) VerifyAsymmetricEC(ctx context.Context, connStr string, message, signature []byte) (bool, error) {
	signatureStr := string(signature)
	expectedSignature := "signed:" + string(message)

	if signatureStr == expectedSignature {
		return true, nil
	}

	return false, fmt.Errorf("invalid signature")
}

func (m *mock) VerifyAsymmetricRSA(ctx context.Context, connStr string, message, signature []byte) (bool, error) {
	signatureStr := string(signature)
	expectedSignature := "signed:" + string(message)

	if signatureStr == expectedSignature {
		return true, nil
	}

	return false, fmt.Errorf("invalid signature")
}
