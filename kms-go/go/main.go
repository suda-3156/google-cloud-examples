/*
 * Consider a better way to specify project_id, location_id, key_ring_name, and key_name.
 *
 */

package main

import (
	"app/gckms"
	"context"
	"log"
	"log/slog"
	"net/http"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"github.com/rs/cors"
)

var gk gckms.GCKMS

func main() {
	lggr := slog.New(slog.NewJSONHandler(
		log.Writer(),
		&slog.HandlerOptions{
			ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
				if a.Key == "time" {
					t := a.Value.Any().(time.Time)
					a.Value = slog.StringValue(t.Format("2006-01-02 15:04:05"))
				}
				return a
			},
			Level: slog.LevelDebug,
		},
	))
	slog.SetDefault(lggr)

	// --- KMS client ---
	ctx := context.Background()
	kmsClient, err := kms.NewKeyManagementClient(ctx)
	if err != nil {
		slog.ErrorContext(
			ctx,
			"Could not create KMS client",
			slog.String("reason", err.Error()),
		)
		return
	}
	defer kmsClient.Close()
	slog.InfoContext(ctx, "KMS client created successfully")

	gk = gckms.New(kmsClient)
	// --- KMS client ---

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthCheckHandler)
	mux.HandleFunc("/list_key_rings", listKeyRingsHandler)
	mux.HandleFunc("/list_keys", listKeysHandler)
	mux.HandleFunc("/encrypt", encryptHandler)
	mux.HandleFunc("/decrypt", decryptHandler)
	mux.HandleFunc("/encrypt_asymmetric", encryptAsymmetricHandler)
	mux.HandleFunc("/decrypt_asymmetric", decryptAsymmetricHandler)
	mux.HandleFunc("/sign_asymmetric", signAsymmetricHandler)
	mux.HandleFunc("/verify_asymmetric", verifyAsymmetricHandler)

	c := cors.New(cors.Options{
		Debug: true,
	})

	handler := c.Handler(mux)

	log.Fatal(http.ListenAndServe(":8080", handler))
}
