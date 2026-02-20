package main

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	statusPending = "PENDING_UPLOAD_VALIDATION"
	statusBuild   = "BUILD_IN_PROGRESS"
	statusDeploy  = "DEPLOY_IN_PROGRESS"
	statusReady   = "READY"
	statusFailed  = "FAILED"
)

type Deployment struct {
	ID            string    `json:"id"`
	ServiceName   string    `json:"serviceName"`
	Namespace     string    `json:"namespace"`
	BundlePath    string    `json:"bundlePath"`
	ExtractedPath string    `json:"extractedPath"`
	Status        string    `json:"status"`
	Revision      string    `json:"revision,omitempty"`
	LogsHint      string    `json:"logsHint"`
	Error         string    `json:"error,omitempty"`
	Output        string    `json:"output,omitempty"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

type Server struct {
	mu            sync.RWMutex
	deployments   map[string]*Deployment
	latestID      string
	idCounter     uint64
	uploadRoot    string
	scriptPath    string
	maxUploadSize int64
	mockDeploy    bool
}

type DeployResponse struct {
	ID      string `json:"id"`
	Status  string `json:"status"`
	Message string `json:"message"`
}

func main() {
	uploadRoot := envOr("UPLOAD_ROOT", filepath.Join(os.TempDir(), "knative-appdev", "uploads"))
	maxUploadSize := int64(50 << 20) // 50MiB
	scriptPath := envOr("BUILD_DEPLOY_SCRIPT", detectScriptPath())

	if err := os.MkdirAll(uploadRoot, 0o755); err != nil {
		log.Fatalf("failed to create upload root: %v", err)
	}

	s := &Server{
		deployments:   map[string]*Deployment{},
		uploadRoot:    uploadRoot,
		scriptPath:    scriptPath,
		maxUploadSize: maxUploadSize,
		mockDeploy:    strings.EqualFold(envOr("MOCK_DEPLOY", "false"), "true"),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/deploy", s.handleDeploy)
	mux.HandleFunc("/status/latest", s.handleLatestStatus)
	mux.HandleFunc("/status/", s.handleStatusByID)

	addr := envOr("PORT", "8080")
	log.Printf("upload-api listening on :%s (script: %s)", addr, scriptPath)
	if err := http.ListenAndServe(":"+addr, loggingMiddleware(mux)); err != nil {
		log.Fatal(err)
	}
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleDeploy(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, s.maxUploadSize)
	if err := r.ParseMultipartForm(s.maxUploadSize); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": fmt.Sprintf("invalid multipart form: %v", err)})
		return
	}

	serviceName := defaultServiceName(r.FormValue("service"))
	namespace := defaultNamespace(r.FormValue("namespace"))

	file, header, err := r.FormFile("bundle")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bundle field is required"})
		return
	}
	defer file.Close()

	if !isSupportedBundle(header.Filename) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bundle must be one of: .zip, .tar, .tar.gz, .tgz"})
		return
	}

	id := s.nextID()
	workDir := filepath.Join(s.uploadRoot, id)
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": fmt.Sprintf("failed to create workdir: %v", err)})
		return
	}

	bundlePath, err := saveBundle(file, header, workDir)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": fmt.Sprintf("failed to save bundle: %v", err)})
		return
	}

	extractPath := filepath.Join(workDir, "src")
	if err := os.MkdirAll(extractPath, 0o755); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": fmt.Sprintf("failed to create extract path: %v", err)})
		return
	}

	if err := extractBundle(bundlePath, extractPath); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": fmt.Sprintf("failed to extract bundle: %v", err)})
		return
	}

	d := &Deployment{
		ID:            id,
		ServiceName:   serviceName,
		Namespace:     namespace,
		BundlePath:    bundlePath,
		ExtractedPath: extractPath,
		Status:        statusPending,
		LogsHint:      logsHint(serviceName, namespace),
		CreatedAt:     time.Now().UTC(),
		UpdatedAt:     time.Now().UTC(),
	}

	s.storeDeployment(d)
	go s.runBuildDeploy(id)

	writeJSON(w, http.StatusAccepted, DeployResponse{
		ID:      id,
		Status:  d.Status,
		Message: "bundle accepted; build and deploy started",
	})
}

func (s *Server) handleLatestStatus(w http.ResponseWriter, _ *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.latestID == "" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "no deployments yet"})
		return
	}
	writeJSON(w, http.StatusOK, s.deployments[s.latestID])
}

func (s *Server) handleStatusByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/status/")
	if id == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing deployment id"})
		return
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
	d, ok := s.deployments[id]
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "deployment not found"})
		return
	}

	writeJSON(w, http.StatusOK, d)
}

func (s *Server) runBuildDeploy(id string) {
	d, ok := s.getDeployment(id)
	if !ok {
		return
	}

	s.updateStatus(id, statusBuild, "", "")
	if s.mockDeploy {
		time.Sleep(1 * time.Second)
		s.updateStatus(id, statusDeploy, "mock deploy executed", "")
		time.Sleep(1 * time.Second)
		s.updateReady(id, "mock deploy executed", "mock-revision-00001")
		return
	}

	cmd := exec.Command(s.scriptPath)
	cmd.Env = append(os.Environ(),
		"APP_DIR="+d.ExtractedPath,
		"SERVICE_NAME="+d.ServiceName,
		"NAMESPACE="+d.Namespace,
		"DEPLOYMENT_ID="+d.ID,
		"IMAGE_TAG="+d.ID,
	)
	output, err := cmd.CombinedOutput()

	if err != nil {
		s.updateStatus(id, statusFailed, string(output), fmt.Sprintf("build/deploy failed: %v", err))
		return
	}

	s.updateStatus(id, statusDeploy, string(output), "")
	revision := latestRevision(d.ServiceName, d.Namespace)
	s.updateReady(id, string(output), revision)
}

func latestRevision(serviceName, namespace string) string {
	cmd := exec.Command(
		"kubectl",
		"get", "revision",
		"-n", namespace,
		"-l", "serving.knative.dev/service="+serviceName,
		"-o", "jsonpath={range .items[*]}{.metadata.name}{"+"\n"+"}{end}",
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return ""
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) == 0 || lines[0] == "" {
		return ""
	}
	sort.Strings(lines)
	return lines[len(lines)-1]
}

func (s *Server) nextID() string {
	n := atomic.AddUint64(&s.idCounter, 1)
	return fmt.Sprintf("dep-%06d", n)
}

func (s *Server) storeDeployment(d *Deployment) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.deployments[d.ID] = d
	s.latestID = d.ID
}

func (s *Server) getDeployment(id string) (*Deployment, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	d, ok := s.deployments[id]
	return d, ok
}

func (s *Server) updateStatus(id, status, output, errMsg string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d, ok := s.deployments[id]
	if !ok {
		return
	}
	d.Status = status
	d.Output = output
	d.Error = errMsg
	d.UpdatedAt = time.Now().UTC()
}

func (s *Server) updateReady(id, output, revision string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d, ok := s.deployments[id]
	if !ok {
		return
	}
	d.Status = statusReady
	d.Output = output
	d.Revision = revision
	d.Error = ""
	d.UpdatedAt = time.Now().UTC()
}

func saveBundle(src multipart.File, header *multipart.FileHeader, workDir string) (string, error) {
	name := filepath.Base(header.Filename)
	dstPath := filepath.Join(workDir, name)
	dst, err := os.Create(dstPath)
	if err != nil {
		return "", err
	}
	defer dst.Close()
	if _, err = io.Copy(dst, src); err != nil {
		return "", err
	}
	return dstPath, nil
}

func extractBundle(bundlePath, outDir string) error {
	lower := strings.ToLower(bundlePath)
	switch {
	case strings.HasSuffix(lower, ".zip"):
		return extractZip(bundlePath, outDir)
	case strings.HasSuffix(lower, ".tar"):
		f, err := os.Open(bundlePath)
		if err != nil {
			return err
		}
		defer f.Close()
		return extractTar(f, outDir)
	case strings.HasSuffix(lower, ".tar.gz"), strings.HasSuffix(lower, ".tgz"):
		f, err := os.Open(bundlePath)
		if err != nil {
			return err
		}
		defer f.Close()
		gr, err := gzip.NewReader(f)
		if err != nil {
			return err
		}
		defer gr.Close()
		return extractTar(gr, outDir)
	default:
		return errors.New("unsupported archive format")
	}
}

func extractZip(path, outDir string) error {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return err
	}
	defer zr.Close()

	for _, f := range zr.File {
		target, err := safeJoin(outDir, f.Name)
		if err != nil {
			return err
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		rc, err := f.Open()
		if err != nil {
			return err
		}
		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
		if err != nil {
			rc.Close()
			return err
		}
		if _, err := io.Copy(out, rc); err != nil {
			rc.Close()
			out.Close()
			return err
		}
		rc.Close()
		out.Close()
	}
	return nil
}

func extractTar(r io.Reader, outDir string) error {
	tr := tar.NewReader(r)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		target, err := safeJoin(outDir, hdr.Name)
		if err != nil {
			return err
		}

		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
			if err != nil {
				return err
			}
			if _, err := io.Copy(out, tr); err != nil {
				out.Close()
				return err
			}
			out.Close()
		}
	}
	return nil
}

func safeJoin(baseDir, name string) (string, error) {
	clean := filepath.Clean(name)
	if strings.HasPrefix(clean, "../") || clean == ".." {
		return "", fmt.Errorf("invalid archive path: %s", name)
	}
	target := filepath.Join(baseDir, clean)
	baseAbs, err := filepath.Abs(baseDir)
	if err != nil {
		return "", err
	}
	targetAbs, err := filepath.Abs(target)
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(targetAbs, baseAbs+string(os.PathSeparator)) && targetAbs != baseAbs {
		return "", fmt.Errorf("archive path escapes output directory: %s", name)
	}
	return target, nil
}

func isSupportedBundle(name string) bool {
	lower := strings.ToLower(name)
	return strings.HasSuffix(lower, ".zip") ||
		strings.HasSuffix(lower, ".tar") ||
		strings.HasSuffix(lower, ".tar.gz") ||
		strings.HasSuffix(lower, ".tgz")
}

func defaultServiceName(raw string) string {
	if raw == "" {
		return "uploaded-app"
	}
	return sanitizeK8sName(raw)
}

func defaultNamespace(raw string) string {
	if raw == "" {
		return "default"
	}
	return sanitizeK8sName(raw)
}

func sanitizeK8sName(v string) string {
	v = strings.ToLower(strings.TrimSpace(v))
	replacer := strings.NewReplacer("_", "-", ".", "-", " ", "-")
	v = replacer.Replace(v)
	out := make([]rune, 0, len(v))
	for _, r := range v {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			out = append(out, r)
		}
	}
	if len(out) == 0 {
		return "default-name"
	}
	result := strings.Trim(string(out), "-")
	if result == "" {
		return "default-name"
	}
	if len(result) > 63 {
		result = result[:63]
	}
	result = strings.Trim(result, "-")
	if result == "" {
		return "default-name"
	}
	return result
}

func logsHint(service, namespace string) string {
	return fmt.Sprintf("kubectl logs -n %s -l serving.knative.dev/service=%s --tail=100", namespace, service)
}

func detectScriptPath() string {
	candidates := []string{
		"scripts/build-deploy-local.sh",
		"../scripts/build-deploy-local.sh",
		"../../scripts/build-deploy-local.sh",
		"scripts/func-build-deploy.sh",
		"../scripts/func-build-deploy.sh",
		"../../scripts/func-build-deploy.sh",
	}
	for _, candidate := range candidates {
		if st, err := os.Stat(candidate); err == nil && !st.IsDir() {
			return candidate
		}
	}
	return "scripts/build-deploy-local.sh"
}

func envOr(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	})
}
