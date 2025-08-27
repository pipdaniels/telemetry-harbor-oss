package general

import (
	"encoding/json"
	"fmt"
	"net/http"

	"go-ingest-service/internal/cache"
	"go-ingest-service/internal/config"
	"go-ingest-service/internal/models"
	"go-ingest-service/internal/utils"

	"github.com/gofiber/fiber/v2"
)

// IngestData handles single data point ingestion.
func IngestData(c *fiber.Ctx) error {
	rawBody := c.Body()
	fmt.Printf("Raw request body: %s\n", string(rawBody))

	var data SensorData
	if err := json.Unmarshal(rawBody, &data); err != nil {
		fmt.Printf("JSON Unmarshal error: %v\n", err)
		return fiber.NewError(http.StatusBadRequest, "Invalid request body")
	}

	if validationErrors := utils.ValidateStruct(&data); len(validationErrors) > 0 {
		return c.Status(http.StatusBadRequest).JSON(models.NewValidationError(validationErrors))
	}

	queuedData := models.QueuedData{
		RetryCount: 0,
		Type:       "general",
		Data:       data,
	}

	dataJSON, err := json.Marshal(queuedData)
	if err != nil {
		return fiber.NewError(http.StatusInternalServerError, "Failed to prepare data for queue")
	}

	if err := cache.RedisClient.RPush(c.Context(), config.AppConfig.IngestQueueName, dataJSON).Err(); err != nil {
		return fiber.NewError(http.StatusInternalServerError, "Failed to queue data for ingestion")
	}

	return c.Status(http.StatusOK).JSON(fiber.Map{
		"status":   "Data received and queued",
		"ship_id":  data.ShipID,
		"cargo_id": data.CargoID,
	})
}

// IngestBatchData now sends the entire batch as a single message.
func IngestBatchData(c *fiber.Ctx) error {
	rawBody := c.Body()
	fmt.Printf("Raw request body: %s\n", string(rawBody))
	
	var batch []SensorData
	if err := json.Unmarshal(rawBody, &batch); err != nil {
		fmt.Printf("JSON Unmarshal error: %v\n", err)
		return fiber.NewError(http.StatusBadRequest, "Invalid request body")
	}

	if len(batch) == 0 {
		return fiber.NewError(http.StatusBadRequest, "Batch cannot be empty")
	}
	
	if validationErrors := utils.ValidateBatch(batch); len(validationErrors) > 0 {
		return c.Status(http.StatusBadRequest).JSON(models.NewValidationError(validationErrors))
	}


	queuedData := models.QueuedData{
		RetryCount: 0,
		Type:       "general",
		Data:       batch,
	}

	dataJSON, err := json.Marshal(queuedData)
	if err != nil {
		return fiber.NewError(http.StatusInternalServerError, "Failed to prepare batch data")
	}

	if err := cache.RedisClient.RPush(c.Context(), config.AppConfig.IngestQueueName, dataJSON).Err(); err != nil {
		return fiber.NewError(http.StatusInternalServerError, "Failed to queue batch data")
	}

	return c.Status(http.StatusOK).JSON(fiber.Map{
		"status": "Batch data received and queued",
		"count":  len(batch),
	})
}
