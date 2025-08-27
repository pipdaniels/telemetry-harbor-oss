package cache

import (
	"context"
	"log"
	"time"

	"go-ingest-service/internal/config"

	"github.com/go-redis/redis/v8"
)

var RedisClient *redis.Client

func ConnectRedis() error {
	cfg := config.AppConfig
	var client *redis.Client

	log.Printf("[Redis] Connecting to Redis directly: %s:%s", cfg.RedisHost, cfg.RedisPort)
	client = redis.NewClient(&redis.Options{
		Addr:     cfg.RedisHost + ":" + cfg.RedisPort,
		Password: cfg.RedisPassword,
		DB:       0,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := client.Ping(ctx).Result()
	if err != nil {
		log.Printf("[Redis] Could not connect to Redis: %v\n", err)
		return err
	}

	RedisClient = client
	log.Println("[Redis] Redis connection established and verified.")
	return nil
}

func CloseRedis() {
	if RedisClient != nil {
		if err := RedisClient.Close(); err != nil {
			log.Printf("[Redis] Error closing Redis connection: %v\n", err)
		} else {
			log.Println("[Redis] Redis connection closed.")
		}
	}
}
