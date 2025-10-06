## Instructions

### Prepare Credentials

Retrieve you temporary credentials from Learner's Lab.
Enter your configuration when prompted:
```
aws configure
```

And set your session token:
```
aws configure set aws_session_token <YOUR-TEMP-SESSION-TOKEBN>
```

### Apply Infrastructure
```
cd terraform
terraform init
terraform apply -auto-approve
```

### Send Requests
Make sure you are in terraform folder

Get public ip address
```
aws ec2 describe-network-interfaces \
--network-interface-ids $(
    aws ecs describe-tasks \
    --cluster $(terraform output -raw ecs_cluster_name) \
    --tasks $(
        aws ecs list-tasks \
        --cluster $(terraform output -raw ecs_cluster_name) \
        --service-name $(terraform output -raw ecs_service_name) \
        --query 'taskArns[0]' --output text
    ) \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
    --output text
) \
--query 'NetworkInterfaces[0].Association.PublicIp' \
--output text
```

Send some requests:
```
curl http://<PUBLIC-IP-ADDRESS>:8080/v1/products/12345
```
Response:
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: Sun, 06 Oct 2025 18:22:30 GMT
Content-Length: 130
{
  "product_id": 12345,
  "sku": "ABC-123-XYZ",
  "manufacturer": "Acme Corporation",
  "category_id": 456,
  "weight": 1250,
  "some_other_id": 789
}

```
curl http://<PUBLIC-IP-ADDRESS>:8080/v1/products/99999
```
Response:
HTTP/1.1 404 Not Found
Content-Type: application/json; charset=utf-8
Date: Sun, 06 Oct 2025 18:22:50 GMT
Content-Length: 110
{
  "error": "NOT_FOUND",
  "message": "Product not found",
  "details": "Product ID must be a positive integer"
}


```
curl -i -X POST http://localhost:8080/v1/products/12345/details \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 12345,
    "sku": "ABC-123-XYZ",
    "manufacturer": "Apple Inc.",
    "category_id": 456,
    "weight": 1250,
    "some_other_id": 789
  }'
```
Response:
HTTP/1.1 204 No Content
Date: Sun, 06 Oct 2025 19:25:31 GMT
Content-Length: 0


```
curl -i -X POST http://localhost:8080/v1/products/12345/details \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 12345,
    "sku": "ABC-123-XYZ",
    "manufacturer": "",
    "category_id": 456,
    "weight": 1250,
    "some_other_id": 789
  }'
```
Response:
{
  "error": "INVALID_INPUT",
  "message": "Provided input data is invalid"
}

## Clean Up
```
terraform destroy -auto-approve
```
