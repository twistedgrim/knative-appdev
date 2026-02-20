FROM rust:1.81-slim AS builder
WORKDIR /app

COPY Cargo.toml ./
COPY src ./src
COPY static ./static

RUN cargo build --release

FROM debian:bookworm-slim
RUN useradd --create-home appuser
WORKDIR /app

COPY --from=builder /app/target/release/rust-webapp /app/rust-webapp
COPY --from=builder /app/static /app/static

ENV PORT=8080
EXPOSE 8080
USER appuser

CMD ["/app/rust-webapp"]
