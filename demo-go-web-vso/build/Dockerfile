# Copyright IBM Corp. 2024, 2026

FROM golang:1.23.0-bullseye AS build

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ ./cmd/
COPY internal/ ./internal/
COPY cmd/server/resources ./resources/
COPY cmd/server/templates ./templates/

RUN GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -ldflags="-s -w -extldflags '-static'" -v -o server ./cmd/server

FROM alpine:3.20 AS publish

FROM scratch
COPY --from=build /app/server /app/server
COPY --from=build /app/templates /app/templates
COPY --from=build /app/resources /app/resources

EXPOSE 8080

ENTRYPOINT ["/app/server"]
