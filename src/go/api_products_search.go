// Package api implements the product search API.
//
// This file contains a fixed-cost search endpoint designed for load testing:
// - Data is generated in-memory at startup (100k products by default).
// - Each request scans a fixed-size window (100 items) to keep CPU cost stable.
// - Results are capped by `limit` (<= 20), independent of the scan size.
// - Concurrency safety: data reads via sync.Map; cursors/counters via atomic.
//
// Go version: 1.19+ (uses atomic.Uint64 methods: Add/Load/Store)
package api

import (
	"net/http"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

//
// ----------------------------- Data Model -----------------------------
//

// SearchProduct is the in-memory representation of a product searchable
// by Name and Category (case-insensitive).
type SearchProduct struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`     // searchable (case-insensitive substring)
	Category    string `json:"category"` // searchable (case-insensitive substring)
	Brand       string `json:"brand"`
	Description string `json:"description"`
}

//
// --------------------------- Global Storage ---------------------------
//
// We maintain two complementary structures:
//
// 1) searchStore (sync.Map): key = product ID, value = SearchProduct
//    - O(1) random access by ID
//    - concurrency-safe reads/writes without external locks
//
// 2) idIndex ([]int): ordered list of all product IDs
//    - enables deterministic, index-based "sliding window" scans
//    - used with a ring index: (base + i) % n
//
// Additionally, two atomic counters are used:
//
// - scanCursor: global scan starting offset (in items)
// - totalChecked: cumulative number of items examined across all requests
//
// Note: atomic.Uint64 is used (Go 1.19+). Use its methods Add/Load/Store.

var (
	searchStore  sync.Map      // all products in a concurrent map (key: ID)
	idIndex      []int         // ordered index of all product IDs
	scanCursor   atomic.Uint64 // next global scan start offset (monotonic, ringed by modulo)
	totalChecked atomic.Uint64 // cumulative items examined since process start
)

//
// --------------------------- Data Seeding -----------------------------
//

// InitSearchData populates the in-memory dataset with n products (defaults to 100,000).
// - Brands/Categories rotate via modulo for a predictable distribution
// - Name format: "Product <Brand> <ID>", e.g., "Product Alpha 1"
// - idIndex pre-allocates capacity to avoid repeated reslices during append
func InitSearchData(n int) {
	if n <= 0 {
		n = 100000
	}

	brands := []string{"Alpha", "Beta", "Gamma", "Delta", "Omega"}
	categories := []string{"Electronics", "Books", "Home", "Toys", "Fashion"}

	// Pre-allocate index capacity for performance (append will not reallocate).
	idIndex = make([]int, 0, n)

	for i := 1; i <= n; i++ {
		// (i-1)%len(...) ensures the very first product is "Alpha" and "Electronics"
		brand := brands[(i-1)%len(brands)]
		cat := categories[(i-1)%len(categories)]

		p := SearchProduct{
			ID:          i,
			Name:        "Product " + brand + " " + strconv.Itoa(i),
			Category:    cat,
			Brand:       brand,
			Description: "lorem ipsum",
		}

		// Write to the concurrent store and append to the ID index.
		searchStore.Store(i, p)
		idIndex = append(idIndex, i)
	}

	// Reset cursors/counters.
	scanCursor.Store(0)
	totalChecked.Store(0)
}

//
// ----------------------------- HTTP API -------------------------------
//
// GET /v1/products/search?q=<term>&limit=<n>
//
// Behavior:
// - Validates query param q (required), limit ∈ (1..20], default 20.
// - Scans a fixed window of 100 items starting from a moving base offset.
//   * base is computed by scanCursor.Add(window)-window so each request
//     starts at a different segment (round-robin), then wrapped by modulo.
// - Matches if q is a case-insensitive substring of Name or Category.
// - Returns up to `limit` matched products, but always scans up to 100 items.
// - Responds with observability fields for load testing:
//   * checked: how many items were examined this request (≈100)
//   * total_checked: cumulative items examined (across all requests)
//   * window_start/window_size: scan parameters
//   * took_ms: elapsed time of this search (ms)
//
// Complexity per request: O(window) = O(100) -> stable CPU cost.
//

// SearchProducts handles the fixed-cost search endpoint.
func (api *ProductsAPI) SearchProducts(c *gin.Context) {
	// --- 1) Parse & validate query parameters ---
	q := strings.TrimSpace(c.Query("q"))
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "INVALID_INPUT",
			"message": "query param q is required",
		})
		return
	}
	q = strings.ToLower(q) // case-insensitive matching

	// limit ∈ (1..20], default 20
	limit := 20
	if ls := c.Query("limit"); ls != "" {
		if l, err := strconv.Atoi(ls); err == nil && l > 0 && l <= 20 {
			limit = l
		}
	}

	start := time.Now()

	// If data is not initialized yet, return an empty result with metrics.
	if len(idIndex) == 0 {
		c.JSON(http.StatusOK, gin.H{
			"hits":          []SearchProduct{},
			"count":         0,
			"checked":       0,
			"took_ms":       0,
			"window":        []int{},             // legacy field kept for safety
			"scanned":       0,                   // legacy field kept for safety
			"total_checked": totalChecked.Load(), // cumulative metric
		})
		return
	}

	// --- 2) Define a fixed-size scan window and compute scan base ---
	const window = 100                           // fixed compute cost per request
	checked := 0                                 // how many items we examined this request
	n := len(idIndex)                            // total dataset size
	base := int(scanCursor.Add(window) - window) // moving start offset (round-robin)
	results := make([]SearchProduct, 0, limit)   // pre-cap results (<= limit)

	// --- 3) Scan exactly `window` items in a ring and collect up to `limit` matches ---
	for i := 0; i < window && checked < window; i++ {
		idx := (base + i) % n // ring index
		id := idIndex[idx]    // fetch product ID from ordered index

		if v, ok := searchStore.Load(id); ok {
			p := v.(SearchProduct)

			// Case-insensitive substring match on Name or Category.
			name := strings.ToLower(p.Name)
			cat := strings.ToLower(p.Category)
			if strings.Contains(name, q) || strings.Contains(cat, q) {
				// Only cap the number of returned results; keep scanning to stabilize compute cost.
				if len(results) < limit {
					results = append(results, p)
				}
			}
		}
		checked++ // always count examined items to reach the fixed window size
	}

	// Update global cumulative metric (atomic & contention-free).
	totalChecked.Add(uint64(checked))

	// --- 4) Respond with results + observability fields ---
	resp := gin.H{
		"hits":          results,                          // matched products (<= limit)
		"count":         len(results),                     // number of matches returned
		"checked":       checked,                          // items examined this request (≈100)
		"total_checked": totalChecked.Load(),              // cumulative items examined
		"took_ms":       time.Since(start).Milliseconds(), // latency in ms
		"window_start":  base,                             // starting offset used this request
		"window_size":   window,                           // fixed window size (100)
	}
	c.JSON(http.StatusOK, resp)
}
