# Docker image for production use
# Step 1: Modules caching
# モジュールに変更がない限り、ダウンロードをスキップする。
FROM golang:1.25-alpine AS modules

WORKDIR /app
COPY ./go.mod ./
COPY ./go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod/ \
    go mod download -x

COPY ./ ./

# Step 2: Server building
FROM modules AS builder
RUN --mount=type=cache,target=/go/pkg/mod/ \
    go build -o /bin/server .

# Step 3: Final image
FROM alpine:latest

# ENV TZ=Asia/Tokyo

COPY --from=builder /bin/server /bin/server

EXPOSE 8080
CMD ["/bin/server"]
