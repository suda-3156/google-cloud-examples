package gckms

import (
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/asn1"
	"encoding/pem"
	"fmt"
	"hash/crc32"
	"math/big"

	"cloud.google.com/go/kms/apiv1/kmspb"
	"google.golang.org/protobuf/types/known/wrapperspb"
)

func (g *gckms) SignAsymmetric(ctx context.Context, connStr string, message string) ([]byte, error) {
	// Convert the message into bytes. Cryptographic plaintexts and
	// ciphertexts are always byte arrays.
	plaintext := []byte(message)

	// Calculate the digest of the message.
	digest := sha256.New()
	if _, err := digest.Write(plaintext); err != nil {
		return nil, fmt.Errorf("failed to create digest: %w", err)
	}

	// Optional but recommended: Compute digest's CRC32C.
	crc32c := func(data []byte) uint32 {
		t := crc32.MakeTable(crc32.Castagnoli)
		return crc32.Checksum(data, t)

	}
	digestCRC32C := crc32c(digest.Sum(nil))

	// Build the signing request.
	//
	// Note: Key algorithms will require a varying hash function. For example,
	// EC_SIGN_P384_SHA384 requires SHA-384.
	req := &kmspb.AsymmetricSignRequest{
		Name: connStr,
		Digest: &kmspb.Digest{
			Digest: &kmspb.Digest_Sha256{
				Sha256: digest.Sum(nil),
			},
		},
		DigestCrc32C: wrapperspb.Int64(int64(digestCRC32C)),
	}

	// Call the API.
	result, err := g.client.AsymmetricSign(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to sign digest: %w", err)
	}

	// Optional, but recommended: perform integrity verification on result.
	// For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
	// https://cloud.google.com/kms/docs/data-integrity-guidelines
	if result.VerifiedDigestCrc32C == false {
		return nil, fmt.Errorf("AsymmetricSign: request corrupted in-transit")
	}
	if result.Name != req.Name {
		return nil, fmt.Errorf("AsymmetricSign: request corrupted in-transit")
	}
	if int64(crc32c(result.Signature)) != result.SignatureCrc32C.Value {
		return nil, fmt.Errorf("AsymmetricSign: response corrupted in-transit")
	}

	return result.Signature, nil
}

func (g *gckms) VerifyAsymmetricEC(ctx context.Context, connStr string, message, signature []byte) (bool, error) {
	// Retrieve the public key from KMS.
	response, err := g.client.GetPublicKey(ctx, &kmspb.GetPublicKeyRequest{Name: connStr})
	if err != nil {
		return false, fmt.Errorf("failed to get public key: %w", err)
	}

	// Parse the public key. Note, this example assumes the public key is in the
	// ECDSA format.
	block, _ := pem.Decode([]byte(response.Pem))
	publicKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false, fmt.Errorf("failed to parse public key: %w", err)
	}
	ecKey, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return false, fmt.Errorf("public key is not elliptic curve")
	}

	// Verify Elliptic Curve signature.
	var parsedSig struct{ R, S *big.Int }
	if _, err = asn1.Unmarshal(signature, &parsedSig); err != nil {
		return false, fmt.Errorf("asn1.Unmarshal: %w", err)
	}

	digest := sha256.Sum256(message)
	if !ecdsa.Verify(ecKey, digest[:], parsedSig.R, parsedSig.S) {
		return false, fmt.Errorf("failed to verify signature")
	}
	return true, nil
}

func (g *gckms) VerifyAsymmetricRSA(ctx context.Context, connStr string, message, signature []byte) (bool, error) {
	// Retrieve the public key from KMS.
	response, err := g.client.GetPublicKey(ctx, &kmspb.GetPublicKeyRequest{Name: connStr})
	if err != nil {
		return false, fmt.Errorf("failed to get public key: %w", err)
	}

	// Parse the public key. Note, this example assumes the public key is in the
	// RSA format.
	block, _ := pem.Decode([]byte(response.Pem))
	publicKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false, fmt.Errorf("failed to parse public key: %w", err)
	}
	rsaKey, ok := publicKey.(*rsa.PublicKey)
	if !ok {
		return false, fmt.Errorf("public key is not rsa")
	}

	// Verify the RSA signature.
	digest := sha256.Sum256(message)
	if err := rsa.VerifyPSS(rsaKey, crypto.SHA256, digest[:], signature, &rsa.PSSOptions{
		SaltLength: len(digest),
		Hash:       crypto.SHA256,
	}); err != nil {
		return false, fmt.Errorf("failed to verify signature: %w", err)
	}

	return true, nil
}
