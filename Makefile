.PHONY: dev build clean help docker-build docker-tag docker-push docker-push-all

# 二进制文件名
BINARY_NAME=go-short
BIN_DIR=bin

# Docker 配置
DOCKER_USERNAME ?= jianboo
DOCKER_IMAGE = $(DOCKER_USERNAME)/go-short
DOCKER_TAG ?= latest

help: ## 显示帮助信息
	@echo "可用命令:"
	@echo "  make dev            - 开发模式运行服务（使用 air 热重载，自动加载 .env 文件）"
	@echo "  make build          - 编译项目到 $(BIN_DIR)/ 目录"
	@echo "  make clean          - 清理编译文件"
	@echo "  make docker-build   - 构建 Docker 镜像"
	@echo "  make docker-tag     - 标记 Docker 镜像（需要设置 DOCKER_USERNAME）"
	@echo "  make docker-push    - 推送 Docker 镜像到 Docker Hub（需要先 docker-login）"
	@echo "  make docker-push-all - 构建、标记并推送镜像（一键操作）"
	@echo ""
	@echo "Docker 使用示例:"
	@echo "  make docker-build DOCKER_USERNAME=your-username"
	@echo "  make docker-push-all DOCKER_USERNAME=your-username DOCKER_TAG=v1.0.0"
	@echo "  make help   - 显示帮助信息"

dev: ## 开发模式运行（使用 air 热重载）
	@echo "启动开发服务器（使用 air 热重载）..."
	@if ! command -v air > /dev/null; then \
		echo "错误: air 未安装，请先安装 air: go install github.com/cosmtrek/air@latest"; \
		exit 1; \
	fi
	@if [ -f .env ]; then \
		echo "加载 .env 文件..."; \
		export $$(grep -v '^#' .env | grep -v '^$$' | xargs) && air; \
	else \
		air; \
	fi

build: ## 编译项目
	@echo "编译项目..."
	@mkdir -p $(BIN_DIR)
	GOOS=linux GOARCH=amd64 go build -o $(BIN_DIR)/$(BINARY_NAME)-linux-amd64 main.go
	GOOS=darwin GOARCH=amd64 go build -o $(BIN_DIR)/$(BINARY_NAME)-darwin-amd64 main.go
	GOOS=darwin GOARCH=arm64 go build -o $(BIN_DIR)/$(BINARY_NAME)-darwin-arm64 main.go
	GOOS=windows GOARCH=amd64 go build -o $(BIN_DIR)/$(BINARY_NAME)-windows-amd64.exe main.go
	@echo "编译完成！二进制文件在 $(BIN_DIR)/ 目录下"

clean: ## 清理编译文件
	@echo "清理编译文件..."
	@rm -rf $(BIN_DIR)
	@echo "清理完成！"

docker-build: ## 构建 Docker 镜像
	@echo "构建 Docker 镜像..."
	@echo "注意: 如果构建失败，请确保 Docker 支持多平台构建"
	docker build --platform linux/amd64 -t $(BINARY_NAME):$(DOCKER_TAG) .
	@echo "构建完成！镜像名称: $(BINARY_NAME):$(DOCKER_TAG)"

docker-tag: ## 标记 Docker 镜像
	@echo "标记 Docker 镜像..."
	@if [ "$(DOCKER_USERNAME)" = "your-username" ]; then \
		echo "错误: 请设置 DOCKER_USERNAME 环境变量"; \
		echo "例如: make docker-tag DOCKER_USERNAME=your-username"; \
		exit 1; \
	fi
	docker tag $(BINARY_NAME):$(DOCKER_TAG) $(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "标记完成！镜像名称: $(DOCKER_IMAGE):$(DOCKER_TAG)"

docker-push: ## 推送 Docker 镜像到 Docker Hub
	@echo "推送 Docker 镜像到 Docker Hub..."
	@if [ "$(DOCKER_USERNAME)" = "your-username" ]; then \
		echo "错误: 请设置 DOCKER_USERNAME 环境变量"; \
		echo "例如: make docker-push DOCKER_USERNAME=your-username"; \
		exit 1; \
	fi
	@echo "请确保已经登录 Docker Hub (docker login)"
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "推送完成！镜像地址: https://hub.docker.com/r/$(DOCKER_IMAGE)"

docker-push-all: docker-build docker-tag docker-push ## 构建、标记并推送镜像（一键操作）
	@echo "✅ 完成！镜像已推送到 Docker Hub"
	@echo "镜像地址: https://hub.docker.com/r/$(DOCKER_IMAGE)"
	@echo "拉取命令: docker pull $(DOCKER_IMAGE):$(DOCKER_TAG)"
