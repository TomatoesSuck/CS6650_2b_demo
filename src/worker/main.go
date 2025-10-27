package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	sqs "github.com/aws/aws-sdk-go-v2/service/sqs"
)

// Item and Order represent the message structure stored in SQS
type Item struct {
	SKU string `json:"sku"`
	Qty int    `json:"qty"`
}

type Order struct {
	OrderID    string    `json:"order_id"`
	CustomerID int       `json:"customer_id"`
	Status     string    `json:"status"`
	Items      []Item    `json:"items"`
	CreatedAt  time.Time `json:"created_at"`
}

// gate limits the maximum concurrent payment processing
var gate chan struct{}

// Simulate a 3-second payment verification
func verifyPaymentSync() {
	gate <- struct{}{}
	defer func() { <-gate }()
	time.Sleep(3 * time.Second)
}

func main() {
	// Load environment variables
	region := os.Getenv("AWS_REGION")
	queueURL := os.Getenv("SQS_QUEUE_URL")
	cc := 10
	if v := os.Getenv("WORKER_CONCURRENCY"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cc = n
		}
	}
	gate = make(chan struct{}, cc)

	// Initialize AWS SQS client
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		log.Fatal(err)
	}
	client := sqs.NewFromConfig(cfg)

	log.Printf("Worker started; queue=%s cc=%d\n", queueURL, cc)

	// Main polling loop
	for {
		out, err := client.ReceiveMessage(context.Background(), &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20,
			VisibilityTimeout:   30,
		})
		if err != nil {
			log.Printf("receive error: %v", err)
			time.Sleep(time.Second)
			continue
		}
		if len(out.Messages) == 0 {
			continue
		}

		// Process each message concurrently
		for _, m := range out.Messages {
			msg := m
			go func() {
				var order Order
				if err := json.Unmarshal([]byte(*msg.Body), &order); err != nil {
					log.Printf("bad message: %v", err)
					// Delete malformed message
					_, _ = client.DeleteMessage(context.Background(), &sqs.DeleteMessageInput{
						QueueUrl:      aws.String(queueURL),
						ReceiptHandle: msg.ReceiptHandle,
					})
					return
				}

				verifyPaymentSync()
				order.Status = "completed"
				log.Printf("Processed order=%s", order.OrderID)

				// Delete message after successful processing
				_, err := client.DeleteMessage(context.Background(), &sqs.DeleteMessageInput{
					QueueUrl:      aws.String(queueURL),
					ReceiptHandle: msg.ReceiptHandle,
				})
				if err != nil {
					log.Printf("delete failed: %v", err)
				}
			}()
		}
	}
}
