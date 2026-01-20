# 超轻量级短链接服务

开箱即用，仅配置域名即可

数据库使用 SQLite

## 快速开始

1. 安装依赖
```bash
go mod download
```

2. 安装 Air（用于开发模式热重载，可选）
```bash
go install github.com/cosmtrek/air@latest
```

3. 配置环境变量（可选）
```bash
# 复制示例配置文件
cp env.example .env

# 编辑 .env 文件或直接设置环境变量
export DOMAIN=short.example.com
export BASE_PATH=/s/
export PORT=8080
export DB_PATH=./data/shortlinks.db
export CODE_LENGTH=4
```

4. 运行服务
```bash
# 开发模式（使用 air 热重载，推荐）
make dev

# 或直接运行
go run main.go
```

3. 创建短链接
```bash
curl -X POST http://localhost:8080/shorten \
  -H "Content-Type: application/json" \
  -d '{"long_url": "https://www.example.com"}'
```

4. 访问短链接
```bash
curl http://localhost:8080/1
```

## 环境变量配置

- `DOMAIN` - 自定义域名（可选，用于生成短链接URL），例如: `short.example.com` 或 `localhost:8080`
- `BASE_PATH` - 基础路径（可选，默认为空），例如: `/s/` 表示短链接在 `/s/xxx`，留空表示短链接在根路径 `/xxx`
- `PORT` - 服务端口（可选，默认 8080）
- `DB_PATH` - 数据库路径（可选，默认 ./data/shortlinks.db）
- `CODE_LENGTH` - 短链接码长度（可选，默认 4）
- `API_KEY` - API Key（可选，如果设置则创建短链接时需要验证），需要在请求头中添加 `X-API-Key` 或 `Authorization: Bearer <key>`

## API 接口

### POST /shorten - 创建短链接

创建短链接，返回短链接码和完整短链接 URL。

**请求参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `url` | string | 是 | 需要缩短的原始 URL |

**请求头：**

如果配置了 `API_KEY`，需要在请求头中添加：
- `X-API-Key: your-api-key` 或
- `Authorization: Bearer your-api-key`

**请求示例：**

```bash
# 基本请求（未配置 API_KEY）
curl -X POST http://localhost:8080/shorten \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.example.com"}'

# 带 API Key 的请求
curl -X POST http://localhost:8080/shorten \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-key" \
  -d '{"url": "https://www.example.com"}'

# 使用 Authorization 头
curl -X POST http://localhost:8080/shorten \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-key" \
  -d '{"url": "https://www.example.com"}'
```

**响应示例：**

```json
{
  "code": "abc123",
  "short_url": "http://short.example.com/abc123",
  "url": "https://www.example.com",
  "visit_count": 0
}
```

**响应字段说明：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `code` | string | 短链接码 |
| `short_url` | string | 完整的短链接 URL |
| `url` | string | 原始 URL |
| `visit_count` | number | 访问次数（初始为 0） |

**注意事项：**

- 同一个 URL 多次请求会返回相同的短链接码
- URL 会自动规范化（没有协议会自动添加 `//`）
- 如果 URL 格式不正确，会返回 400 错误

### GET /:code - 访问短链接

访问短链接，自动重定向到原始 URL。

**路径参数：**

| 参数 | 说明 |
|------|------|
| `code` | 短链接码 |

**请求示例：**

```bash
# 访问短链接
curl -L http://localhost:8080/abc123

# 或使用浏览器直接访问
# http://localhost:8080/abc123
```

**响应：**

- 302/301 重定向到原始 URL
- 404 如果短链接不存在

### GET /health - 健康检查

检查服务运行状态。

**请求示例：**

```bash
curl http://localhost:8080/health
```

**响应示例：**

```json
{
  "status": "ok"
}
```

## 使用示例

### 配置自定义域名和路径
```bash
export DOMAIN=short.example.com
export BASE_PATH=/s/
go run main.go
```

生成的短链接格式：`http://short.example.com/s/1`

### 不使用基础路径
```bash
export DOMAIN=short.example.com
go run main.go
```

生成的短链接格式：`http://short.example.com/1`

## Docker 部署

### 构建镜像
```bash
docker build -t go-short .
```

### 运行容器
```bash
docker run -d \
  --name go-short \
  -p 8080:8080 \
  -e DOMAIN=short.example.com \
  -e PORT=8080 \
  -e API_KEY=your-secret-key \
  -v $(pwd)/data:/app/data \
  go-short
```

### 使用 docker-compose
创建 `docker-compose.yml` 文件：
```yaml
version: '3.8'

services:
  go-short:
    image: jianboo/go-short:latest
    container_name: go-short
    ports:
      - "8100:8080"
    environment:
      - BASE_PATH=
      - DOMAIN=
      - API_KEY=
      - CODE_LENGTH=4
    volumes:
      - go_short_data:/app/data
    restart: unless-stopped

volumes:
  go_short_data:
    driver: local

```

然后运行：
```bash
docker-compose up -d
```


# 1. 构建镜像
docker build -t go-short .

# 2. 标记镜像（替换 jianboo 为你的用户名）
docker tag go-short jianboo/go-short:latest

# 3. 登录 Docker Hub
docker login

# 4. 推送镜像
docker push jianboo/go-short:latest
```

## Nginx 配置

项目提供了 `nginx.conf.example` 配置文件示例，包含以下场景：

### 示例 1: 自定义域名
```nginx
server {
    listen 80;
    server_name short.example.com;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**环境变量配置：**
```bash
DOMAIN=short.example.com
PORT=8080
```

### 示例 2: 二级目录
```nginx
server {
    listen 80;
    server_name example.com;
    
    location /s/ {
        proxy_pass http://127.0.0.1:8080/s/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /shorten {
        proxy_pass http://127.0.0.1:8080/shorten;
    }
}
```

**环境变量配置：**
```bash
DOMAIN=example.com
BASE_PATH=/s/
PORT=8080
```

### 部署步骤

1. 复制配置文件：
```bash
sudo cp nginx.conf.example /etc/nginx/sites-available/go-short
```

2. 创建软链接：
```bash
sudo ln -s /etc/nginx/sites-available/go-short /etc/nginx/sites-enabled/
```

3. 测试配置：
```bash
sudo nginx -t
```

4. 重载配置：
```bash
sudo nginx -s reload
# 或
sudo systemctl reload nginx
```

更多配置示例请查看 `nginx.conf.example` 文件。