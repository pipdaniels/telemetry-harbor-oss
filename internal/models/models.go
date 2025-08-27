package models

import "net/http"

// QueuedData is the generic wrapper for any data pushed to the queue.
type QueuedData struct {
	RetryCount int         `json:"retry_count"`
	Type       string      `json:"type"` // e.g., "general", "gps"
	Data       interface{} `json:"data"`
}

// ErrorDetail and ErrorResponse are for structured API error messages.
type ErrorDetail struct {
	Loc  []string `json:"loc"`
	Msg  string   `json:"msg"`
	Type string   `json:"type"`
}

type ErrorResponse struct {
	StatusCode int    `json:"status_code"`
	Message    string `json:"message"`
}

func NewValidationError(details []ErrorDetail) ErrorResponse {
	return ErrorResponse{
		StatusCode: http.StatusBadRequest,
		Message:    "Validation Error",
	}
}
