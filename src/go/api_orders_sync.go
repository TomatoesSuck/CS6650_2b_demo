package api

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Item Structure
type Item struct {
	SKU   string `json:"sku"`
	Qty   int    `json:"qty"`
	Price int    `json:"price,omitempty"`
}

// Order structure
type Order struct {
	OrderID    string    `json:"order_id"`
	CustomerID int       `json:"customer_id"`
	Status     string    `json:"status"` // pending, processing, completed
	Items      []Item    `json:"items"`
	CreatedAt  time.Time `json:"created_at"`
}

// Buffered channel: A buffer size of 5 means a maximum of 5 orders can be processed at the same time
// Simulating a Payment Bottleneck
var paymentGate = make(chan struct{}, 5)

// Simulates a synchronous payment verification: It takes 3 seconds to complete and is limited by paymentGate concurrency.
func verifyPaymentSync() {
	paymentGate <- struct{}{}        // occupy one "payment slot"
	defer func() { <-paymentGate }() // release the slot when done
	time.Sleep(3 * time.Second)      // simulate 3-second processing delay
}

// POST: /v1/orders/sync
// This endpoint demonstrates synchronous order processing:
//  1. Receive an order
//  2. Verify payment (3s delay)
//  3. Return 200 OK after completion

type OrdersAPI struct{}

// OrdersSync handles a synchronous order request.
func (OrdersAPI) OrdersSync(c *gin.Context) {
	var req Order
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// State transition: pending → processing → completed
	req.Status = "pending"
	req.CreatedAt = time.Now()

	req.Status = "processing"
	start := time.Now()

	verifyPaymentSync()
	lat := time.Since(start)

	req.Status = "completed"

	// Optional: include latency information in the response header
	c.Header("X-Payment-Processing-Latency", lat.String())

	// Return the completed order
	c.JSON(http.StatusOK, req)
}
