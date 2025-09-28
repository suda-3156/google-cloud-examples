/*
 * asymmetric.go contains functions to perform asymmetric encryption and decryption using Google Cloud KMS.
 *
 * Example from the official document.
 * References:
 *   https://cloud.google.com/kms/docs/encrypt-decrypt-rsa?hl=ja
 *
 */

package gckms

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"hash/crc32"

	"cloud.google.com/go/kms/apiv1/kmspb"
	"google.golang.org/protobuf/types/known/wrapperspb"
)

func (g *gckms) EncryptAsymmetric(ctx context.Context, connStr string, plaintext string) ([]byte, error) {
	// Retrieve the public key from Cloud KMS. This is the only operation that
	// involves Cloud KMS. The remaining operations take place on your local
	// machine.
	response, err := g.client.GetPublicKey(ctx, &kmspb.GetPublicKeyRequest{
		Name: connStr,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get public key: %w", err)
	}

	// Parse the public key. Note, this example assumes the public key is in the
	// RSA format.
	block, _ := pem.Decode([]byte(response.Pem))
	publicKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse public key: %w", err)
	}
	rsaKey, ok := publicKey.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("public key is not rsa")
	}

	// Convert the message into bytes. Cryptographic plaintexts and
	// ciphertexts are always byte arrays.
	plaintextBytes := []byte(plaintext)

	// Encrypt data using the RSA public key.
	ciphertext, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, rsaKey, plaintextBytes, nil)
	if err != nil {
		return nil, fmt.Errorf("rsa.EncryptOAEP: %w", err)
	}
	return ciphertext, nil
}

func (g *gckms) DecryptAsymmetric(ctx context.Context, connStr string, ciphertext []byte) (string, error) {
	// Optional but recommended: Compute ciphertext's CRC32C.
	crc32c := func(data []byte) uint32 {
		t := crc32.MakeTable(crc32.Castagnoli)
		return crc32.Checksum(data, t)
	}
	ciphertextCRC32C := crc32c(ciphertext)

	// Build the request.
	req := &kmspb.AsymmetricDecryptRequest{
		Name:             connStr,
		Ciphertext:       ciphertext,
		CiphertextCrc32C: wrapperspb.Int64(int64(ciphertextCRC32C)),
	}

	// Call the API.
	result, err := g.client.AsymmetricDecrypt(ctx, req)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt ciphertext: %w", err)
	}

	// Optional, but recommended: perform integrity verification on result.
	// For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
	// https://cloud.google.com/kms/docs/data-integrity-guidelines
	if result.VerifiedCiphertextCrc32C == false {
		return "", fmt.Errorf("AsymmetricDecrypt: request corrupted in-transit")
	}
	if int64(crc32c(result.Plaintext)) != result.PlaintextCrc32C.Value {
		return "", fmt.Errorf("AsymmetricDecrypt: response corrupted in-transit")
	}

	return string(result.Plaintext), nil
}
