package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"strings"
	"time"
)

type appRow struct {
	Namespace     string `json:"namespace"`
	Name          string `json:"name"`
	URL           string `json:"url"`
	Ready         string `json:"ready"`
	LatestCreated string `json:"latestCreatedRevision"`
	LatestReady   string `json:"latestReadyRevision"`
	CreatedAt     string `json:"createdAt"`
	Reason        string `json:"reason"`
	Source        string `json:"source"`
}

type ksvcList struct {
	Items []struct {
		Metadata struct {
			Name              string `json:"name"`
			Namespace         string `json:"namespace"`
			CreationTimestamp string `json:"creationTimestamp"`
		} `json:"metadata"`
		Status struct {
			URL                       string `json:"url"`
			LatestCreatedRevisionName string `json:"latestCreatedRevisionName"`
			LatestReadyRevisionName   string `json:"latestReadyRevisionName"`
			Conditions                []struct {
				Type   string `json:"type"`
				Status string `json:"status"`
				Reason string `json:"reason"`
			} `json:"conditions"`
		} `json:"status"`
	} `json:"items"`
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/api/apps", handleApps)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	port := strings.TrimSpace(os.Getenv("PORT"))
	if port == "" {
		port = "8080"
	}

	log.Printf("app-dashboard listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func handleApps(w http.ResponseWriter, _ *http.Request) {
	rows, err := listApps()
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to list apps: %v", err), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(rows)
}

func listApps() ([]appRow, error) {
	if inCluster() {
		return listAppsInCluster()
	}
	return listAppsViaKubectl()
}

func inCluster() bool {
	_, errHost := os.Stat("/var/run/secrets/kubernetes.io/serviceaccount/token")
	return errHost == nil
}

func listAppsInCluster() ([]appRow, error) {
	tokenBytes, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")
	if err != nil {
		return nil, err
	}
	caBytes, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
	if err != nil {
		return nil, err
	}

	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(caBytes) {
		return nil, fmt.Errorf("failed to parse serviceaccount ca")
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{RootCAs: pool},
		},
	}

	req, err := http.NewRequest(http.MethodGet, "https://kubernetes.default.svc/apis/serving.knative.dev/v1/services", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(string(tokenBytes)))

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 2000))
		return nil, fmt.Errorf("kubernetes api status %d: %s", res.StatusCode, string(body))
	}

	var list ksvcList
	if err := json.NewDecoder(res.Body).Decode(&list); err != nil {
		return nil, err
	}
	rows := toRows(list, "in-cluster-api")
	sortRows(rows)
	return rows, nil
}

func listAppsViaKubectl() ([]appRow, error) {
	cmd := exec.Command("kubectl", "get", "ksvc", "-A", "-o", "json")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var list ksvcList
	if err := json.Unmarshal(out, &list); err != nil {
		return nil, err
	}
	rows := toRows(list, "kubectl")
	sortRows(rows)
	return rows, nil
}

func toRows(list ksvcList, source string) []appRow {
	rows := make([]appRow, 0, len(list.Items))
	for _, item := range list.Items {
		ready, reason := conditionReady(item.Status.Conditions)
		rows = append(rows, appRow{
			Namespace:     item.Metadata.Namespace,
			Name:          item.Metadata.Name,
			URL:           item.Status.URL,
			Ready:         ready,
			LatestCreated: item.Status.LatestCreatedRevisionName,
			LatestReady:   item.Status.LatestReadyRevisionName,
			CreatedAt:     item.Metadata.CreationTimestamp,
			Reason:        reason,
			Source:        source,
		})
	}
	return rows
}

func conditionReady(conditions []struct {
	Type   string `json:"type"`
	Status string `json:"status"`
	Reason string `json:"reason"`
}) (string, string) {
	for _, c := range conditions {
		if c.Type == "Ready" {
			return c.Status, c.Reason
		}
	}
	return "Unknown", ""
}

func sortRows(rows []appRow) {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Namespace == rows[j].Namespace {
			return rows[i].Name < rows[j].Name
		}
		return rows[i].Namespace < rows[j].Namespace
	})
}

func handleIndex(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(indexHTML))
}

const indexHTML = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Application Dashboard</title>
    <style>
      :root {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color-scheme: light;
      }
      body {
        margin: 0;
        background: linear-gradient(180deg, #f8fafc, #eef2ff);
        color: #0f172a;
      }
      .wrap {
        max-width: 980px;
        margin: 0 auto;
        padding: 24px;
      }
      .card {
        background: #fff;
        border: 1px solid #dbe4f0;
        border-radius: 12px;
        box-shadow: 0 10px 20px rgba(2, 6, 23, 0.06);
        overflow: hidden;
      }
      h1 {
        margin: 0 0 8px;
      }
      .muted {
        color: #475569;
        margin-bottom: 16px;
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        padding: 10px 12px;
        border-bottom: 1px solid #e2e8f0;
        text-align: left;
        font-size: 14px;
      }
      th {
        background: #f8fafc;
      }
      .ready-True { color: #166534; font-weight: 600; }
      .ready-False { color: #991b1b; font-weight: 600; }
      .ready-Unknown { color: #92400e; font-weight: 600; }
      .actions {
        margin: 12px 0 18px;
      }
      button {
        background: #0f172a;
        color: #fff;
        border: 0;
        border-radius: 8px;
        padding: 9px 14px;
        cursor: pointer;
      }
      code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <h1>Application Developer Platform Dashboard</h1>
      <p class="muted">Knative services currently built and running in the cluster.</p>
      <div class="actions">
        <button onclick="loadApps()">Refresh</button>
      </div>
      <div class="card">
        <table>
          <thead>
            <tr>
              <th>Namespace</th>
              <th>Name</th>
              <th>Ready</th>
              <th>Latest Created</th>
              <th>Latest Ready</th>
              <th>URL</th>
              <th>Reason</th>
            </tr>
          </thead>
          <tbody id="rows">
            <tr><td colspan="7">Loading...</td></tr>
          </tbody>
        </table>
      </div>
      <p class="muted">Source: <code id="source">-</code></p>
    </div>
    <script>
      async function loadApps() {
        const rows = document.getElementById('rows');
        rows.innerHTML = '<tr><td colspan="7">Loading...</td></tr>';
        try {
          const res = await fetch('/api/apps');
          if (!res.ok) throw new Error('status ' + res.status);
          const data = await res.json();
          if (!Array.isArray(data) || data.length === 0) {
            rows.innerHTML = '<tr><td colspan="7">No applications found</td></tr>';
            return;
          }
          document.getElementById('source').textContent = data[0].source || '-';
          rows.innerHTML = data.map(function(app) {
            var link = '';
            if (app.url) {
              var safeUrl = escapeHtml(app.url);
              link = '<a href="' + safeUrl + '" target="_blank" rel="noreferrer">' + safeUrl + '</a>';
            }
            return '<tr>' +
              '<td>' + escapeHtml(app.namespace) + '</td>' +
              '<td>' + escapeHtml(app.name) + '</td>' +
              '<td class="ready-' + escapeHtml(app.ready) + '">' + escapeHtml(app.ready) + '</td>' +
              '<td>' + escapeHtml(app.latestCreatedRevision || '') + '</td>' +
              '<td>' + escapeHtml(app.latestReadyRevision || '') + '</td>' +
              '<td>' + link + '</td>' +
              '<td>' + escapeHtml(app.reason || '') + '</td>' +
              '</tr>';
          }).join('');
        } catch (err) {
          rows.innerHTML = '<tr><td colspan="7">Failed to load: ' + escapeHtml(String(err)) + '</td></tr>';
        }
      }
      function escapeHtml(v) {
        return String(v)
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');
      }
      loadApps();
    </script>
  </body>
</html>`
