"""
Simple-eStore Performance Test (GET & POST only)
-----------------------------------------------
Simulates realistic traffic to test key API responses:
  - GET  /v1/products/:id        → 200 / 404 / 500
  - POST /v1/products/:id/details → 204 / 400 / 404 / 500
"""
from locust import HttpUser, task, between
import json, os

HOST_DEFAULT = os.getenv("LOCUST_HOST", "http://localhost:8080")

# IDs mapped to your server behavior:
PRODUCT_OK = 12345      # exists → GET 200 / POST 204
PRODUCT_404 = 54321     # not exists → GET/POST 404
PRODUCT_GET_500 = 50000 # in init(): "this is not a Product" → GET 500
PRODUCT_POST_500 = 99999# in POST handler: panic when id==99999 → POST 500

# ----- Bodies must match your struct types (int32 for ids/weight, strings for sku/manufacturer) -----
VALID_BODY = {
    # missing productId is fine
    "sku": "DEF-456-QWE",
    "manufacturer": "Beta Corp",
    "category_id": 456,      # int
    "weight": 800,           # int
    "some_other_id": 22      # int
}

INVALID_BODY_MISSING = {
    # missing productId is fine
    "sku": "",  # invalid
    "manufacturer": "X",
    "category_id": 1,
    "weight": 100,
    "some_other_id": 1
}


MISMATCH_ID_BODY = {
    "product_id": 999,
    "sku": "OK",
    "manufacturer": "OK",
    "category_id": 1,
    "weight": 100,
    "some_other_id": 1
}


class SimpleEStoreUser(HttpUser):
    host = HOST_DEFAULT
    wait_time = between(0.05, 0.2)

    # ---------------- GET: 200 / 404 / 500 ----------------
    @task
    def get_200(self):
        self.client.get(f"/v1/products/{PRODUCT_OK}", name="GET /v1/products/:id [200]")

    @task
    def get_404(self):
        self.client.get(f"/v1/products/{PRODUCT_404}", name="GET /v1/products/:id [404]")

    @task
    def get_500(self):
        self.client.get(f"/v1/products/{PRODUCT_GET_500}", name="GET /v1/products/:id [500]")

    # --------------- POST: 204 / 400 / 404 / 500 ---------------
    @task
    def post_204(self):
        self.client.post(
            f"/v1/products/{PRODUCT_OK}/details",
            headers={"Content-Type": "application/json"},
            data=json.dumps(VALID_BODY),
            name="POST /v1/products/:id/details [204]"
        )

    @task
    def post_400_missing(self):
        self.client.post(
            f"/v1/products/{PRODUCT_OK}/details",
            headers={"Content-Type": "application/json"},
            data=json.dumps(INVALID_BODY_MISSING),
            name="POST /v1/products/:id/details [400-missing/invalid]"
        )


    @task
    def post_400_mismatch(self):
        self.client.post(
            f"/v1/products/{PRODUCT_OK}/details",
            headers={"Content-Type": "application/json"},
            data=json.dumps(MISMATCH_ID_BODY),
            name="POST /v1/products/:id/details [400-mismatch-id]"
        )

    @task
    def post_404(self):
        self.client.post(
            f"/v1/products/{PRODUCT_404}/details",
            headers={"Content-Type": "application/json"},
            data=json.dumps(VALID_BODY),
            name="POST /v1/products/:id/details [404]"
        )

    @task
    def post_500(self):
        self.client.post(
            f"/v1/products/{PRODUCT_POST_500}/details",
            headers={"Content-Type": "application/json"},
            data=json.dumps(VALID_BODY),
            name="POST /v1/products/:id/details [500]"
        )