#!/bin/bash

set -e

AWS_REGION="us-east-1"
ECR_REPOSITORY="604275788475.dkr.ecr.us-east-1.amazonaws.com/devops-app"
IMAGE_TAG="$1"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: Image tag is required."
  echo "Usage: $0 <image-tag>"
  exit 1
fi

CONTAINER_NAME="devops-app"
MYSQL_CONTAINER="mysql"
NETWORK_NAME="devops-network"
SECRET_NAME="devops-app/db-password"

echo "Logging in to Amazon ECR..."

aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REPOSITORY"

echo "ECR login successful."

echo "Pulling image: $ECR_REPOSITORY:$IMAGE_TAG"

docker pull "$ECR_REPOSITORY:$IMAGE_TAG"

echo "Image pulled successfully."


echo "Retrieving database password from AWS Secrets Manager..."

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text)

echo "Database secret retrieved successfully."



echo "Stopping old application container..."

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo "Old application container removed."


echo "Starting new application container..."

docker run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  --restart unless-stopped \
  -p 8080:8080 \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://$MYSQL_CONTAINER:3306/devopsdb" \
  -e SPRING_DATASOURCE_USERNAME="devops" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  "$ECR_REPOSITORY:$IMAGE_TAG"

echo "Application container started."

echo "Waiting for application to become healthy..."

for i in {1..30}; do
  if curl -fsS http://localhost:8080/health; then
    echo
    echo "Deployment successful."
    exit 0
  fi

  echo "Application not ready yet... attempt $i/30"
  sleep 2
done

echo "Application failed to become healthy."
docker logs "$CONTAINER_NAME"
exit 1
