package api

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	sns "github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/gin-gonic/gin"
)

type OrdersAsyncAPI struct {
	sns      *sns.Client // AWS SNS client used to publish messages
	topicArn string      // ARN of the SNS topic for order events
}

// NewOrdersAsyncAPI initializes a new OrdersAsyncAPI instance.
// It loads AWS credentials/configuration from the default provider chain (local, EC2, or Fargate).
func NewOrdersAsyncAPI() *OrdersAsyncAPI {
	cfg, _ := config.LoadDefaultConfig(context.Background())
	return &OrdersAsyncAPI{
		sns:      sns.NewFromConfig(cfg),
		topicArn: os.Getenv("SNS_TOPIC_ARN"), // e.g. arn:aws:sns:us-east-1:123456789012:order-processing-events
	}
}

// OrdersAsync handles POST /orders/async.
// Instead of blocking to process payments synchronously,
// this endpoint immediately publishes the order to an SNS topic
// so it can be processed asynchronously by downstream workers.
//
// Flow:
//  1. Parse the incoming JSON request.
//  2. Set order status = "received" and timestamp.
//  3. Publish order data as JSON to SNS.
//  4. Return HTTP 202 Accepted to the client immediately.
func (a *OrdersAsyncAPI) OrdersAsync(c *gin.Context) {
	var order Order
	if err := c.ShouldBindJSON(&order); err != nil {
		// Invalid JSON request body
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Initialize order metadata
	order.Status = "received"
	order.CreatedAt = time.Now()

	// Ensure SNS topic is configured
	if a.topicArn == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "missing_topic_arn"})
		return
	}

	// Marshal order struct into JSON message
	body, _ := json.Marshal(order)

	// Publish to SNS (non-blocking for clients)
	_, err := a.sns.Publish(
		c.Request.Context(), // Reuse HTTP request context for tracing/cancellation
		&sns.PublishInput{
			TopicArn: aws.String(a.topicArn),
			Message:  aws.String(string(body)),
		},
	)
	if err != nil {
		// Return error if SNS publish fails
		c.JSON(http.StatusInternalServerError, gin.H{"error": "publish_failed", "detail": err.Error()})
		return
	}

	// Respond immediately — client doesn't wait for payment completion
	c.JSON(http.StatusAccepted, gin.H{
		"status":   "accepted",
		"order_id": order.OrderID,
		"note":     "Queued for processing via SNS/SQS",
	})
}
