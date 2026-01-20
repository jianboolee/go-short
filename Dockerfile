# 构建阶段
FROM golang:1.21-alpine AS builder

# 安装构建依赖（SQLite 需要 CGO）
RUN apk add --no-cache gcc musl-dev sqlite-dev

# 设置工作目录
WORKDIR /build

# 复制 go mod 文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 构建应用（添加 CGO 标志以修复 Alpine/musl libc 兼容性问题）
RUN CGO_ENABLED=1 GOOS=linux CGO_CFLAGS="-D_LARGEFILE64_SOURCE" go build -a -installsuffix cgo -o go-short main.go

# 运行阶段
FROM alpine:latest

# 安装运行时依赖（SQLite 和 wget 用于健康检查）
RUN apk --no-cache add ca-certificates sqlite wget

# 创建非 root 用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/go-short .

# 创建数据目录
RUN mkdir -p /app/data && chown -R appuser:appgroup /app

# 设置默认环境变量
ENV PORT=8080
ENV DB_PATH=/app/data/shortlinks.db
ENV CODE_LENGTH=4
ENV DOMAIN=""
ENV BASE_PATH=""
ENV API_KEY=""

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# 启动应用
CMD ["./go-short"]
