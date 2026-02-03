package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	nanoid "github.com/matoous/go-nanoid/v2"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type ShortLink struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	Code       string    `gorm:"uniqueIndex;not null" json:"code"`
	URL        string    `gorm:"not null" json:"url" binding:"required"`
	VisitCount uint      `gorm:"default:0" json:"visit_count"`
	CreatedAt  time.Time `json:"created_at"`
}

type Config struct {
	Domain     string // 自定义域名，如 short.example.com
	BasePath   string // 基础路径，如 /s/ 或空字符串
	Port       string // 服务端口
	DBPath     string // 数据库路径
	CodeLength int    // 短链接码长度，默认 4
	APIKey     string // API Key，如果设置则需要验证
}

var db *gorm.DB
var config Config

func loadConfig() {
	config.Domain = os.Getenv("DOMAIN")

	config.BasePath = os.Getenv("BASE_PATH")
	if config.BasePath != "" {
		// 确保路径以 / 开头
		if !strings.HasPrefix(config.BasePath, "/") {
			config.BasePath = "/" + config.BasePath
		}
		// 确保路径以 / 结尾
		if !strings.HasSuffix(config.BasePath, "/") {
			config.BasePath += "/"
		}
	} else {
		config.BasePath = "/"
	}

	config.Port = os.Getenv("PORT")
	if config.Port == "" {
		config.Port = "8080"
	}

	config.DBPath = os.Getenv("DB_PATH")
	if config.DBPath == "" {
		config.DBPath = "./data/shortlinks.db"
	}

	// 读取短链接码长度，默认 4
	codeLengthStr := os.Getenv("CODE_LENGTH")
	if codeLengthStr == "" {
		config.CodeLength = 4
	} else {
		length, err := strconv.Atoi(codeLengthStr)
		if err != nil || length <= 0 {
			config.CodeLength = 4
		} else {
			config.CodeLength = length
		}
	}

	// 读取 API Key（可选）
	config.APIKey = os.Getenv("API_KEY")
}

func initDB() {
	// 确保数据库目录存在
	dbDir := filepath.Dir(config.DBPath)
	if dbDir != "." && dbDir != "" {
		err := os.MkdirAll(dbDir, 0755)
		if err != nil {
			log.Fatalf("创建数据库目录失败: %v", err)
		}
	}

	var err error
	db, err = gorm.Open(sqlite.Open(config.DBPath), &gorm.Config{})
	if err != nil {
		log.Fatalf("初始化数据库失败: %v", err)
	}

	// 自动迁移
	err = db.AutoMigrate(&ShortLink{})
	if err != nil {
		log.Fatalf("数据库迁移失败: %v", err)
	}
}

// 生成短链接码（使用 nanoid）
func generateCode() (string, error) {
	// 默认字符集：0-9a-zA-Z（62个字符）
	const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return nanoid.Generate(alphabet, config.CodeLength)
}

// 规范化 URL，支持“任意协议”
func normalizeURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	if strings.Contains(raw, "://") || strings.HasPrefix(raw, "//") {
		return raw
	}

	return "//" + raw
}

// 创建短链接
func createShortLink(c *gin.Context) {
	// 如果配置了 API Key，验证请求中的 Key
	if config.APIKey != "" {
		// 从请求头获取 API Key（支持 X-API-Key 或 Authorization）
		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			// 尝试从 Authorization 头获取（格式：Bearer <key> 或直接 <key>）
			authHeader := c.GetHeader("Authorization")
			if authHeader != "" {
				apiKey = strings.TrimPrefix(authHeader, "Bearer ")
				apiKey = strings.TrimSpace(apiKey)
			}
		}

		// 验证 API Key
		if apiKey != config.APIKey {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "无效的 API Key"})
			return
		}
	}

	var req struct {
		URL string `json:"url" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 规范化 URL
	normalizedURL := normalizeURL(req.URL)

	// 检查 URL 是否已经存在
	var link ShortLink
	var code string
	result := db.Where("url = ?", normalizedURL).First(&link)
	if result.Error == nil {
		// URL 已存在，返回已有的 code
		code = link.Code
	} else if result.Error == gorm.ErrRecordNotFound {
		// URL 不存在，创建新记录
		// 生成唯一的短链接码
		var err error
		maxRetries := 10
		for i := 0; i < maxRetries; i++ {
			code, err = generateCode()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "生成短链接码失败"})
				return
			}

			// 检查 code 是否已存在
			var codeCheck ShortLink
			codeResult := db.Where("code = ?", code).First(&codeCheck)
			if codeResult.Error == gorm.ErrRecordNotFound {
				// code 不存在，可以使用
				break
			}
			if i == maxRetries-1 {
				// 重试次数用完，返回错误
				c.JSON(http.StatusInternalServerError, gin.H{"error": "生成唯一短链接码失败，请重试"})
				return
			}
		}

		// 创建新记录
		link = ShortLink{
			Code: code,
			URL:  normalizedURL,
		}
		if err := db.Create(&link).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
			return
		}
	} else {
		// 数据库查询错误
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}

	// 生成短链接URL
	protocol := "http"
	if c.Request.TLS != nil {
		protocol = "https"
	}

	// 如果自定义域名为空，使用当前请求的 Host
	domain := config.Domain
	if domain == "" {
		domain = c.Request.Host
	}

	// 确保 BASE_PATH 正确处理（如果为空，使用 /）
	basePath := config.BasePath

	shortURL := fmt.Sprintf("%s://%s%s%s", protocol, domain, basePath, code)
	c.JSON(http.StatusOK, gin.H{
		"code":        code,
		"short_url":   shortURL,
		"url":         link.URL,
		"visit_count": link.VisitCount,
	})
}

// 重定向到原始URL
func redirect(c *gin.Context) {
	code := c.Param("code")
	var link ShortLink
	if err := db.Where("code = ?", code).First(&link).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "短链接不存在"})
		return
	}

	// 增加访问次数
	db.Model(&link).Update("visit_count", gorm.Expr("visit_count + 1"))

	c.Redirect(http.StatusMovedPermanently, link.URL)
}

func main() {
	// 加载配置
	loadConfig()

	initDB()

	r := gin.Default()

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// 创建短链接
	r.POST("/shorten", createShortLink)

	// 无基础路径，直接在根路径
	r.GET("/:code", redirect)

	addr := ":" + config.Port
	fmt.Printf("服务启动在 %s\n", addr)
	fmt.Printf("域名: %s\n", config.Domain)
	fmt.Printf("基础路径: %s\n", config.BasePath)
	log.Fatal(r.Run(addr))
}
