package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"reflect"
	"sync"
	"syscall"
	"time"

	"go-ingest-service/internal/cache"
	"go-ingest-service/internal/config"
	"go-ingest-service/internal/db"
	"go-ingest-service/internal/ingest/general"
	"go-ingest-service/internal/models"

	"github.com/go-redis/redis/v8"
	"github.com/jackc/pgx/v4"
)

const maxRetries = 3
const numWorkers = 10 // Number of concurrent DB workers

// main sets up the application, health check server, and starts the worker pool.
func main() {
	if err := config.LoadConfig(); err != nil {
		log.Fatalf("[Worker] Failed to load configuration: %v", err)
	}

	if err := db.ConnectDB(); err != nil {
		log.Fatalf("[Worker] Failed to connect to database: %v", err)
	}
	defer db.CloseDB()

	if err := cache.ConnectRedis(); err != nil {
		log.Fatalf("[Worker] Failed to connect to Redis: %v", err)
	}
	defer cache.CloseRedis()

	// Create the HTTP server for health checks.
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthzHandler)

	// It's good practice to make the port configurable.
	healthCheckAddr := ":8001"
	httpServer := &http.Server{
		Addr:    healthCheckAddr,
		Handler: mux,
	}

	// Start the health check server in a separate goroutine.
	go func() {
		log.Printf("[Healthz] Health check server starting on %s", healthCheckAddr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[Healthz] Could not listen on %s: %v\n", healthCheckAddr, err)
		}
	}()

	log.Printf("[Worker] Go Ingest Worker started. Queue: %s, Concurrency: %d",
		config.AppConfig.IngestQueueName, numWorkers)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	jobChan := make(chan models.QueuedData, config.AppConfig.WorkerBatchSize)

	// Start the pool of database workers
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go dbWorker(ctx, &wg, i+1, jobChan)
	}

	// Start the main loop to fetch from Redis and dispatch to workers
	go dispatcherLoop(ctx, jobChan)

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigChan
	log.Printf("[Worker] Received signal %v, shutting down...", sig)

	// Create a context for the server shutdown.
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	// Shutdown the HTTP server gracefully.
	log.Println("[Healthz] Shutting down health check server...")
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("[Healthz] Server shutdown failed: %v", err)
	}

	// Signal workers to stop and wait for them to finish.
	cancel()
	close(jobChan)
	wg.Wait()

	log.Println("[Worker] Go Ingest Worker shut down gracefully.")
}

// dispatcherLoop fetches jobs from Redis and sends them to the worker pool.
func dispatcherLoop(ctx context.Context, jobChan chan<- models.QueuedData) {
	for {
		select {
		case <-ctx.Done():
			log.Println("[Dispatcher] Context cancelled, stopping.")
			return
		default:
			result, err := cache.RedisClient.BLPop(ctx, 1*time.Second, config.AppConfig.IngestQueueName).Result()
			if err != nil {
				if err != redis.Nil && err != context.Canceled {
					log.Printf("[Dispatcher] Error popping from Redis: %v", err)
					time.Sleep(5 * time.Second)
				}
				continue
			}

			var item models.QueuedData
			if err := json.Unmarshal([]byte(result[1]), &item); err != nil {
				log.Printf("[Dispatcher] Unmarshal error, moving to DLQ: %v. Data: %s", err, result[1])
				moveToDLQ(ctx, result[1])
				continue
			}
			jobChan <- item
		}
	}
}

// dbWorker receives jobs and processes them.
func dbWorker(ctx context.Context, wg *sync.WaitGroup, id int, jobChan <-chan models.QueuedData) {
	defer wg.Done()
	log.Printf("[DBWorker %d] Started.", id)
	for item := range jobChan {
		var finalErr error
		switch item.Type {
		case "general":
			batch, err := normalizeToBatch(item.Data)
			if err != nil {
				log.Printf("[DBWorker %d] Type mismatch for 'general' data, moving to DLQ: %v", id, err)
				moveToDLQ(ctx, item)
				continue
			}

			if err := insertGeneralBatchWithCopy(ctx, batch); err != nil {
				finalErr = fmt.Errorf("failed to insert batch: %w", err)
			}
		default:
			log.Printf("[DBWorker %d] Unknown data type '%s' in queue, moving to DLQ.", id, item.Type)
			moveToDLQ(ctx, item)
			continue
		}

		if finalErr != nil {
			log.Printf("[DBWorker %d] Failed to insert batch (type: %s): %v. Handling retry.", id, item.Type, finalErr)
			handleFailedItem(ctx, item)
		} else {
			log.Printf("[DBWorker %d] Successfully inserted batch (type: %s).", id, item.Type)
		}
	}
	log.Printf("[DBWorker %d] Shutting down.", id)
}

// handleFailedItem manages the retry logic for a failed job.
func handleFailedItem(ctx context.Context, item models.QueuedData) {
	item.RetryCount++
	if item.RetryCount > maxRetries {
		log.Printf("[Worker] Item exceeded max retries (%d). Moving to DLQ. Type: %s", maxRetries, item.Type)
		moveToDLQ(ctx, item)
		return
	}

	itemJSON, err := json.Marshal(item)
	if err != nil {
		log.Printf("[Worker] CRITICAL: Failed to re-marshal for re-queue, moving to DLQ. Error: %v", err)
		moveToDLQ(ctx, item)
		return
	}
	if err := cache.RedisClient.RPush(ctx, config.AppConfig.IngestQueueName, string(itemJSON)).Err(); err != nil {
		log.Printf("[Worker] CRITICAL: Failed to re-queue item. Moving to DLQ. Error: %v", err)
		moveToDLQ(ctx, item)
	}
}

// moveToDLQ sends a job that cannot be processed to the Dead Letter Queue.
func moveToDLQ(ctx context.Context, item interface{}) {
	dlqName := config.AppConfig.IngestQueueName + "_dlq"
	dataJSON, err := json.Marshal(item)
	if err != nil {
		log.Printf("[Worker] CRITICAL: Failed to marshal item for DLQ. Error: %v", err)
		return
	}
	if err := cache.RedisClient.RPush(ctx, dlqName, dataJSON).Err(); err != nil {
		log.Printf("[Worker] CRITICAL: Failed to move item to DLQ '%s'. DATA: %s", dlqName, string(dataJSON))
	}
}

// normalizeToBatch is a helper that ensures we always have a slice to work with.
func normalizeToBatch(data interface{}) ([]general.SensorData, error) {
	if reflect.TypeOf(data).Kind() == reflect.Slice {
		var batch []general.SensorData
		dataBytes, _ := json.Marshal(data)
		if err := json.Unmarshal(dataBytes, &batch); err != nil {
			return nil, err
		}
		return batch, nil
	}

	var singleItem general.SensorData
	dataBytes, _ := json.Marshal(data)
	if err := json.Unmarshal(dataBytes, &singleItem); err != nil {
		return nil, err
	}
	return []general.SensorData{singleItem}, nil
}

// healthzHandler checks the health of dependencies (DB, Redis).
func healthzHandler(w http.ResponseWriter, r *http.Request) {
	// Use a short timeout to prevent health checks from hanging.
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	// Check PostgreSQL Connection
	if err := db.Pool.Ping(ctx); err != nil {
		log.Printf("[Healthz] DB ping failed: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status":   "error",
			"database": "unhealthy",
		})
		return
	}

	// Check Redis Connection
	if _, err := cache.RedisClient.Ping(ctx).Result(); err != nil {
		log.Printf("[Healthz] Redis ping failed: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "error",
			"redis":  "unhealthy",
		})
		return
	}

	// If all checks pass, return 200 OK.
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":   "ok",
		"database": "healthy",
		"redis":    "healthy",
	})
}


// insertGeneralBatchWithCopy uses a temporary table and the COPY protocol for efficient batch inserts.
func insertGeneralBatchWithCopy(ctx context.Context, batch []general.SensorData) error {
	if len(batch) == 0 {
		return nil
	}


	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	tempTableName := fmt.Sprintf("temp_ingest_%d", time.Now().UnixNano())
	createTempTableSQL := fmt.Sprintf(`
		CREATE TEMP TABLE %s (
			time TIMESTAMPTZ NOT NULL,
			ship_id TEXT NOT NULL,
			cargo_id TEXT NOT NULL,
			value DOUBLE PRECISION
		) ON COMMIT DROP;`, tempTableName)

	if _, err := tx.Exec(ctx, createTempTableSQL); err != nil {
		return fmt.Errorf("failed to create temp table: %w", err)
	}

	columns := []string{"time", "ship_id", "cargo_id", "value"}
	rows := make([][]interface{}, 0, len(batch))
	for _, data := range batch {
		if data.Value == nil {
			continue
		}
		rows = append(rows, []interface{}{data.Time, data.ShipID, data.CargoID, *data.Value})
	}

	if len(rows) == 0 {
		// Commit transaction to ensure temp table is dropped.
		return tx.Commit(ctx)
	}

	_, err = tx.CopyFrom(
		ctx,
		pgx.Identifier{tempTableName},
		columns,
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		return fmt.Errorf("failed to copy data to temp table: %w", err)
	}

	insertFromTempSQL := fmt.Sprintf(`
		INSERT INTO cargo_data (time, ship_id, cargo_id, value)
		SELECT time, ship_id, cargo_id, value FROM %s
		ON CONFLICT (time, ship_id, cargo_id) DO NOTHING;`,
		pgx.Identifier{tempTableName}.Sanitize(),
	)

	if _, err := tx.Exec(ctx, insertFromTempSQL); err != nil {
		return fmt.Errorf("failed to insert from temp table: %w", err)
	}

	return tx.Commit(ctx)
}
