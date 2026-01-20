# 构建阶段
FROM golang:1.24-alpine AS builder

WORKDIR /app

# 安装依赖
RUN apk add --no-cache gcc musl-dev sqlite-dev

# 复制go模块文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
# RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/bin/server main.go
RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 CGO_CFLAGS="-D_LARGEFILE64_SOURCE" go build -a -installsuffix cgo -o /app/bin/server main.go

# 运行阶段
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata curl sqlite

WORKDIR /app


# 复制可执行文件
COPY --from=builder /app/bin/server /app/server

# 设置默认环境变量
ENV PORT=8080
ENV DB_PATH=/app/data/shortlinks.db
ENV CODE_LENGTH=4
ENV DOMAIN=""
ENV BASE_PATH=""
ENV API_KEY=""

# # 创建非root用户
# RUN addgroup -g 1001 -S appgroup && \
#     adduser -u 1001 -S appuser -G appgroup && \
#     chown -R appuser:appgroup /app

# # 切换用户
# USER appuser

# 健康检查
HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 暴露端口
EXPOSE 8080

# 启动命令（使用环境变量配置，不需要配置文件参数）
ENTRYPOINT ["/app/server"]