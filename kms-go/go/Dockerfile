# Docker image for production use
# Step 1: Modules caching
# モジュールに変更がない限り、ダウンロードをスキップする。
FROM golang:1.25.1-alpine AS modules

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

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
FROM scratch

# ENV TZ=Asia/Tokyo
# ARG app_version=v0.0.0
# ENV APP_VERSION=$app_version

COPY --from=builder /bin/server /bin/server

EXPOSE 8080
CMD ["/bin/server"]
