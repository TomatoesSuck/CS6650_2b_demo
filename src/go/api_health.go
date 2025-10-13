package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type HealthAPI struct{}

// GET /health
func (api *HealthAPI) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"message": "service healthy",
	})
}
