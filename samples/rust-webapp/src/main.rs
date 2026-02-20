use axum::{extract::State, response::IntoResponse, routing::get, Json, Router};
use chrono::Utc;
use serde::Serialize;
use std::{
    env,
    net::SocketAddr,
    sync::{Arc, atomic::{AtomicU64, Ordering}},
};
use tower_http::services::ServeDir;

#[derive(Clone)]
struct AppState {
    counter: Arc<AtomicU64>,
}

#[derive(Serialize)]
struct MessageResponse {
    message: String,
    counter: u64,
    timestamp: String,
}

#[tokio::main]
async fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{port}")
        .parse()
        .expect("invalid PORT value");

    let state = AppState {
        counter: Arc::new(AtomicU64::new(0)),
    };

    let static_service = ServeDir::new("./static").append_index_html_on_directories(true);

    let app = Router::new()
        .route("/api/message", get(get_message))
        .nest_service("/", static_service)
        .with_state(state);

    println!("rust-webapp listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.expect("failed to bind");
    axum::serve(listener, app).await.expect("server error");
}

async fn get_message(State(state): State<AppState>) -> impl IntoResponse {
    let count = state.counter.fetch_add(1, Ordering::SeqCst) + 1;
    Json(MessageResponse {
        message: "Hello from Rust backend".to_string(),
        counter: count,
        timestamp: Utc::now().to_rfc3339(),
    })
}
