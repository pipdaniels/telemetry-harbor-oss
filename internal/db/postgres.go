// In /db/postgres.go
package db

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v4/pgxpool"
	"go-ingest-service/internal/config"
)

var Pool *pgxpool.Pool

// ConnectDB establishes a configured connection pool to the database.
func ConnectDB() error {
	cfg := config.AppConfig
	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		cfg.DatabaseUser,
		cfg.DatabasePassword,
		cfg.DatabaseHost,
		cfg.DatabasePort, 
		cfg.DatabaseName,
	)

	poolConfig, err := pgxpool.ParseConfig(connStr)
	if err != nil {
		log.Printf("[DB] Unable to parse connection string: %v\n", err)
		return err
	}

	
	poolConfig.MaxConns = 10 // A sensible default for a service with moderate concurrency.

	poolConfig.MaxConnLifetime = 0
	poolConfig.MaxConnIdleTime = 0

	log.Printf("[DB] Attempting to connect to Database: %s:%s", cfg.DatabaseHost, cfg.DatabasePort)
	Pool, err = pgxpool.ConnectConfig(context.Background(), poolConfig)
	if err != nil {
		log.Printf("[DB] Unable to create connection pool: %v\n", err)
		return err
	}

	if err = Pool.Ping(context.Background()); err != nil {
		log.Printf("[DB] Failed to ping database: %v\n", err)
		Pool.Close()
		return err
	}

	log.Println("[DB] Database connection established and verified.")
	return nil
}

// CloseDB closes all connections in the pool.
func CloseDB() {
	if Pool != nil {
		Pool.Close()
		log.Println("[DB] Database connection pool closed.")
	}
}
