package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type infoResponse struct {
	Message   string `json:"message"`
	Time      string `json:"time"`
	Framework string `json:"framework"`
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/info", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(infoResponse{
			Message:   "Hello from sample-go-webapp",
			Time:      time.Now().UTC().Format(time.RFC3339),
			Framework: "Go net/http",
		})
	})

	fs := http.FileServer(http.Dir("./static"))
	mux.Handle("/", fs)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("sample-go-webapp listening on %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
