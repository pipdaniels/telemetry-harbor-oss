package config

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Env               string
	Port              string
	DatabaseUser      string
	DatabasePassword  string
	DatabaseHost      string
	DatabasePort      string
	DatabaseName      string
	RedisHost         string
	RedisPort         string
	RedisPassword     string
    APIKey 			  string
	IngestQueueName       string
	WorkerBatchSize       int
	WorkerPollInterval    time.Duration
	APP_URL            string
}

var AppConfig *Config

func LoadConfig() error {
	// Load .env file in development
	if os.Getenv("APP_ENV") == "" || os.Getenv("APP_ENV") == "dev" {
		err := godotenv.Load()
		if err != nil {
			log.Println("[Config] No .env file found, assuming environment variables are set.")
		}
	}

	AppConfig = &Config{
		Env:                getEnv("APP_ENV", "dev"),
		Port:               getEnv("PORT", "8001"),
		DatabaseUser:       getEnv("DATABASE_USER", ""),
		DatabasePassword:   getEnv("DATABASE_PASSWORD", ""),
		DatabaseHost:       getEnv("DATABASE_HOST", "localhost"),
		DatabasePort:       getEnv("DATABASE_PORT", "5432"),
		DatabaseName:       getEnv("DATABASE_NAME", "database"),
		RedisHost:          getEnv("REDIS_HOST", "localhost"),
		RedisPort:          getEnv("REDIS_PORT", "6379"),
		RedisPassword:      getEnv("REDIS_PASSWORD", ""),
		APIKey:             getEnv("API_KEY", ""),
		IngestQueueName:    getEnv("INGEST_QUEUE_NAME", "ingest_queue"),
		WorkerBatchSize:    getEnvAsInt("WORKER_BATCH_SIZE", 1000),
		WorkerPollInterval: time.Duration(getEnvAsInt("WORKER_POLL_INTERVAL_MS", 1000)) * time.Millisecond,
		APP_URL: 			getEnv("APP_URL", "http://localhost:8001"),

	}
	log.Println("[Config] Configuration loaded successfully.")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if valueStr, exists := os.LookupEnv(key); exists {
		if value, err := strconv.Atoi(valueStr); err == nil {
			return value
		}
	}
	return defaultValue
}
