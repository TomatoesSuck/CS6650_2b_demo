"""
Locust performance test script for Product Search API.

Purpose:
--------
This script is used to simulate concurrent users searching for products
against the backend endpoint `/v1/products/search`.

It helps measure:
- System response time under concurrent load.
- Whether the backend always scans exactly 100 products (fixed compute cost).
- Whether the response structure remains correct under stress.

Test Scenarios:
---------------
- Test 1 (Baseline):   5 users for 2 minutes → expect CPU ~60%, fast response.
- Test 2 (Breaking):   20 users for 3 minutes → expect CPU ~100%, slower response.

Expected Backend Behavior:
--------------------------
Each request:
  - Scans exactly 100 products (`checked == 100`).
  - Returns up to `limit` (<= 20) results in `hits`.
  - Returns HTTP 200 with valid JSON.
"""

from locust import FastHttpUser, task, constant
import random
import json

# Predefined search terms to simulate realistic queries
QUERIES = [
    "alpha", "beta", "gamma", "delta", "omega",            # brand names
    "electronics", "books", "home", "toys", "fashion",     # categories
    "product"                                              # general keyword
]


class ProductSearchUser(FastHttpUser):
    """
    A simulated user that repeatedly performs search queries
    against the /v1/products/search endpoint.

    FastHttpUser is used for better performance (lower latency)
    than the standard HttpUser.
    """

    # No delay between requests — maximum sustained load
    wait_time = constant(0)

    @task
    def search(self):
        """
        Perform one search query.

        1. Randomly pick a query word (brand/category/name).
        2. Send GET /v1/products/search?q=<term>&limit=20.
        3. Validate:
           - HTTP 200 status.
           - JSON is valid.
           - 'checked' == 100 (fixed compute cost).
           - count <= 20 and 'hits' field present.
        """
        q = random.choice(QUERIES)

        # Send GET request to the product search endpoint
        with self.client.get(
                f"/v1/products/search?q={q}&limit=20",
                name="/v1/products/search",
                # fail if request > 2s
                timeout=2.0,             # Type:ignore
                catch_response=True
        ) as resp:
            # Validate HTTP status
            if resp.status_code != 200:
                resp.failure(f"HTTP {resp.status_code}")
                return

            # Validate JSON format
            try:
                data = resp.json()
            except json.JSONDecodeError:
                resp.failure("Invalid JSON")
                return

            # Validate backend logic — must always check 100 items
            if data.get("checked") != 100:
                resp.failure(f"checked != 100 (got {data.get('checked')})")
                return

            # Lightweight payload check
            if data.get("count", 0) > 20 or "hits" not in data:
                resp.failure("bad payload")
                return

            # All checks passed
            resp.success()