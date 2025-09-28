/*
 * list.go contains functions to list key rings and keys in Google Cloud KMS.
 *
 * Example from the official document.
 * References:
 *   https://cloud.google.com/kms/docs/reference/libraries?hl=ja#client-libraries-install-go
 *
 */

package gckms

import (
	"context"
	"fmt"

	"cloud.google.com/go/kms/apiv1/kmspb"
	"google.golang.org/api/iterator"
)

func (g *gckms) ListKeyRings(ctx context.Context, projectID, locationID string) ([]string, error) {
	// Create the request.
	req := &kmspb.ListKeyRingsRequest{
		Parent: fmt.Sprintf("projects/%s/locations/%s", projectID, locationID),
	}

	// List the keyRings.
	it := g.client.ListKeyRings(ctx, req)

	// Iterate over the results.
	var keyRings []string
	for {
		keyRing, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}
		keyRings = append(keyRings, keyRing.Name)
	}
	return keyRings, nil
}

func (g *gckms) ListKeys(ctx context.Context, projectID, locationID, keyRingName string) ([]string, error) {
	// Create the request.
	req := &kmspb.ListCryptoKeysRequest{
		Parent: fmt.Sprintf("projects/%s/locations/%s/keyRings/%s", projectID, locationID, keyRingName),
	}

	// List the keys.
	it := g.client.ListCryptoKeys(ctx, req)

	// Iterate over the results.
	var keys []string
	for {
		key, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}
		keys = append(keys, key.Name)
	}
	return keys, nil
}
