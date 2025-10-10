package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"regexp"
	"time"
)

type Service struct {
	port string

	projectID   string
	region      string
	serviceName string
	revision    string
	color       string
	version     string
	message     string
}

func newService() (*Service, error) {
	projectID, err := getProjectID()
	if err != nil {
		slog.Error("failed to get project ID", slog.String("reason", err.Error()))
		return nil, err
	}

	region, err := getRegion()
	if err != nil {
		slog.Error("failed to get region", slog.String("reason", err.Error()))
		return nil, err
	}

	port := os.Getenv("PORT")
	if port == "" {
		slog.Warn("PORT environment variable not set, defaulting to 8080")
		port = "8080"
	}

	return &Service{
		port:        port,
		projectID:   projectID,
		region:      region,
		serviceName: os.Getenv("K_SERVICE"),
		revision:    os.Getenv("K_REVISION"),
		color:       os.Getenv("COLOR"),
		version:     os.Getenv("APP_VERSION"),
		message:     os.Getenv("MESSAGE"),
	}, nil
}

func (s *Service) run() error {
	slog.Warn("service is running")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		slog.Info(
			"request received",
			slog.String("projectId", s.projectID),
			slog.String("region", s.region),
			slog.String("serviceName", s.serviceName),
			slog.String("revision", s.revision),
			slog.String("color", s.color),
			slog.String("appVersion", s.version),
			slog.String("message", s.message),
		)

		response := map[string]interface{}{
			"status": "OK",
			"time":   time.Now().Format(time.RFC3339),
			"data": map[string]string{
				"projectId":   s.projectID,
				"region":      s.region,
				"serviceName": s.serviceName,
				"revision":    s.revision,
				"color":       s.color,
				"appVersion":  s.version,
				"message":     s.message,
			},
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)

		jsonData, err := json.MarshalIndent(response, "", "  ")
		if err != nil {
			slog.ErrorContext(r.Context(), "Failed to marshal response",
				slog.String("reason", err.Error()),
			)
			return
		}

		if _, err := w.Write(jsonData); err != nil {
			slog.ErrorContext(r.Context(), "Failed to write response",
				slog.String("reason", err.Error()),
			)
		}
	})

	if err := http.ListenAndServe(":"+s.port, nil); err != http.ErrServerClosed {
		return err
	}

	return nil
}

type Job struct {
	projectID string
	jobName   string
	version   string
	message   string
}

func newJob() (*Job, error) {
	projectID, err := getProjectID()
	if err != nil {
		return nil, err
	}

	return &Job{
		projectID: projectID,
		jobName:   os.Getenv("CLOUD_RUN_JOB"),
		version:   os.Getenv("APP_VERSION"),
		message:   os.Getenv("MESSAGE"),
	}, nil
}

func (j *Job) run() error {
	slog.Warn("job is running")

	slog.Info(j.message,
		"projectId", j.projectID,
		"jobName", j.jobName,
		"appVersion", j.version,
	)

	slog.Warn("job finished")

	return nil
}

func getProjectID() (string, error) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://metadata.google.internal/computeMetadata/v1/project/project-id", nil)
	req.Header.Set("Metadata-Flavor", "Google")
	res, err := client.Do(req)
	if err != nil {
		slog.Error("failed to get project ID", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		slog.Error("failed to get project ID", slog.Int("statusCode", res.StatusCode))
		return "UNDEFINED", fmt.Errorf("failed to get project ID: status code %d", res.StatusCode)
	}

	responseBody, err := io.ReadAll(res.Body)
	if err != nil {
		slog.Error("failed to read response body", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}

	return string(responseBody), nil
}

func getRegion() (string, error) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://metadata.google.internal/computeMetadata/v1/instance/region", nil)
	req.Header.Set("Metadata-Flavor", "Google")
	res, err := client.Do(req)
	if err != nil {
		slog.Error("failed to get region", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		slog.Error("failed to get region", slog.Int("statusCode", res.StatusCode))
		return "UNDEFINED", fmt.Errorf("failed to get region: status code %d", res.StatusCode)
	}

	responseBody, err := io.ReadAll(res.Body)
	if err != nil {
		slog.Error("failed to read response body", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}

	region := regexp.MustCompile(`projects/[^/]*/regions/`).ReplaceAllString(string(responseBody), "")

	if region != "" {
		return region, nil
	}

	req, _ = http.NewRequest("GET", "http://metadata.google.internal/computeMetadata/v1/instance/zone", nil)
	req.Header.Set("Metadata-Flavor", "Google")
	res, err = client.Do(req)
	if err != nil {
		slog.Error("failed to get zone", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		slog.Error("failed to get zone", slog.Int("statusCode", res.StatusCode))
		return "UNDEFINED", fmt.Errorf("failed to get zone: status code %d", res.StatusCode)
	}

	responseBody, err = io.ReadAll(res.Body)
	if err != nil {
		slog.Error("failed to read response body", slog.String("error", err.Error()))
		return "UNDEFINED", err
	}

	zone := regexp.MustCompile(`projects/[^/]*/zones/`).ReplaceAllString(string(responseBody), "")

	if zone != "" {
		return "Zone (fallback): " + zone, nil
	}

	return "UNDEFINED", nil
}

func main() {
	slog.Warn("app is starting")

	if os.Getenv("CLOUD_RUN_JOB") == "" {
		s, err := newService()
		if err != nil {
			panic(err)
		}
		if err := s.run(); err != nil {
			panic(err)
		}
	} else {
		j, err := newJob()
		if err != nil {
			panic(err)
		}
		if err := j.run(); err != nil {
			panic(err)
		}
	}

	slog.Warn("app finished")
}
