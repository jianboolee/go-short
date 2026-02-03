# Go Short - 超轻量级短链接服务

一个开箱即用的短链接服务，使用 Go + Gin + GORM + SQLite 构建。

## 特性

- 🚀 **开箱即用** - 无需复杂配置，快速部署
- 📦 **轻量级** - 基于 SQLite，无外部依赖
- 🔐 **安全** - 支持 API Key 验证
- 📊 **统计** - 自动统计访问次数
- 🔄 **去重** - 相同 URL 返回相同短链接码
- 🐳 **Docker 支持** - 提供完整的 Docker 镜像

## 快速开始

### 使用 Docker

```bash
# 拉取镜像
docker pull jianboo/go-short:latest

# 运行容器
docker run -d \
  --name go-short \
  -p 8080:8080 \
  -e DOMAIN=short.example.com \
  -e API_KEY=your-secret-key \
  -v $(pwd)/data:/app/data \
  jianboo/go-short:latest
```

### 使用 docker-compose

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

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `DOMAIN` | 自定义域名 | - |
| `PORT` | 服务端口 | 8080 |
| `BASE_PATH` | 基础路径 | / |
| `DB_PATH` | 数据库路径 | /app/data/shortlinks.db |
| `CODE_LENGTH` | 短链接码长度 | 4 |
| `API_KEY` | API Key（可选） | - |

## API 接口

- `POST /shorten` - 创建短链接
- `GET /:code` - 访问短链接（自动重定向）
- `GET /health` - 健康检查

## 使用示例

```bash
# 创建短链接
curl -X POST http://localhost:8080/shorten \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-key" \
  -d '{"url": "https://www.example.com"}'

# 访问短链接
curl -L http://localhost:8080/abc123
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

## 更多信息

- GitHub: https://github.com/jianboolee/go-short
- 文档: 查看项目 README.md

## License

MIT License


