FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN go build -o /out/app ./main.go

FROM alpine:3.20
WORKDIR /app
COPY --from=build /out/app ./app
ENV PORT=8080
EXPOSE 8080
CMD ["./app"]
