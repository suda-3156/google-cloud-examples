package main

import (
	"encoding/json"
	"log"
	"log/slog"
	"net/http"
	"time"

	"github.com/rs/cors"
)

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

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthCheckHandler)

	c := cors.New(cors.Options{
		Debug: true,
	})

	handler := c.Handler(mux)

	log.Fatal(http.ListenAndServe(":8080", handler))
}

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
