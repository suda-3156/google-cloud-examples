package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"
)

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Health check endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	response := map[string]interface{}{
		"status": "OK",
		"time":   time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func listKeyRingsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "List Key Rings endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	projectID := r.URL.Query().Get("project_id")
	locationID := r.URL.Query().Get("location_id")

	if projectID == "" || locationID == "" {
		http.Error(w, "Missing project_id or location_id parameter", http.StatusBadRequest)
		return
	}

	keyRings, err := gk.ListKeyRings(ctx, projectID, locationID)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to list key rings",
			slog.String("reason", err.Error()),
			slog.String("project_id", projectID),
			slog.String("location_id", locationID),
		)
		http.Error(w, "Failed to list key rings", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"key_rings": keyRings,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func listKeysHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "List Keys endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	projectID := r.URL.Query().Get("project_id")
	locationID := r.URL.Query().Get("location_id")
	keyRingName := r.URL.Query().Get("key_ring_name")

	if projectID == "" || locationID == "" || keyRingName == "" {
		http.Error(w, "Missing project_id, location_id or key_ring_name parameter", http.StatusBadRequest)
		return
	}

	keys, err := gk.ListKeys(ctx, projectID, locationID, keyRingName)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to list keys",
			slog.String("reason", err.Error()),
			slog.String("project_id", projectID),
			slog.String("location_id", locationID),
			slog.String("key_ring_name", keyRingName),
		)
		http.Error(w, "Failed to list keys", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"keys": keys,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func encryptHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Encrypt endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Plaintext   string `json:"plaintext"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName

	// Call the KMS encrypt function
	ciphertext, err := gk.EncryptSymmetric(ctx, connStr, req.Plaintext)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to encrypt data",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to encrypt data", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"ciphertext": ciphertext,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func decryptHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Decrypt endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Ciphertext  []byte `json:"ciphertext"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName

	// Call the KMS decrypt function
	plaintext, err := gk.DecryptSymmetric(ctx, connStr, req.Ciphertext)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to decrypt data",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to decrypt data", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"plaintext": plaintext,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func encryptAsymmetricHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Asymmetric Encrypt endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Plaintext   string `json:"plaintext"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName + "/cryptoKeyVersions/1"

	// Call the KMS encrypt function
	ciphertext, err := gk.EncryptAsymmetric(ctx, connStr, req.Plaintext)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to encrypt data",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to encrypt data", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"ciphertext": ciphertext,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func decryptAsymmetricHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Asymmetric Decrypt endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Ciphertext  []byte `json:"ciphertext"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName + "/cryptoKeyVersions/1"

	// Call the KMS decrypt function
	plaintext, err := gk.DecryptAsymmetric(ctx, connStr, req.Ciphertext)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to decrypt data",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to decrypt data", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"plaintext": plaintext,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func signAsymmetricHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Asymmetric Sign endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Message     string `json:"message"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName + "/cryptoKeyVersions/1"

	// Call the KMS sign function
	signature, err := gk.SignAsymmetric(ctx, connStr, req.Message)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to sign data",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to sign data", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"signature": signature,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}

func verifyAsymmetricHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slog.InfoContext(ctx, "Asymmetric Verify endpoint hit",
		slog.String("remote_addr", r.RemoteAddr),
	)

	// json body
	var req struct {
		ProjectID   string `json:"project_id"`
		LocationID  string `json:"location_id"`
		KeyRingName string `json:"key_ring_name"`
		KeyName     string `json:"key_name"`
		Message     string `json:"message"`
		Signature   []byte `json:"signature"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.ErrorContext(ctx, "Failed to decode request body",
			slog.String("reason", err.Error()),
		)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	connStr := "projects/" + req.ProjectID + "/locations/" + req.LocationID + "/keyRings/" + req.KeyRingName + "/cryptoKeys/" + req.KeyName + "/cryptoKeyVersions/1"

	// Call the KMS verify function
	valid, err := gk.VerifyAsymmetricRSA(ctx, connStr, []byte(req.Message), req.Signature)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to verify signature",
			slog.String("reason", err.Error()),
			slog.String("project_id", req.ProjectID),
			slog.String("location_id", req.LocationID),
			slog.String("key_ring_name", req.KeyRingName),
			slog.String("key_name", req.KeyName),
		)
		http.Error(w, "Failed to verify signature", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"valid": valid,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.ErrorContext(ctx, "Failed to write response",
			slog.String("reason", err.Error()),
		)
	}
}
