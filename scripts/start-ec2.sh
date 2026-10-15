
#!/usr/bin/env bash
set -Eeuo pipefail

# EC2 restart recovery helper
INSTANCE_ID="i-0ded0f957ec08989b"
AWS_REGION="us-east-1"
SECURITY_GROUP_ID="sg-0d3ef013211fdf6ea"

echo "Checking AWS credentials..."
aws sts get-caller-identity --output table

echo
echo "Checking EC2 instance..."

INSTANCE_INFO=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' \
  --output text)

INSTANCE_STATE=$(awk '{print $1}' <<< "$INSTANCE_INFO")
EC2_PUBLIC_IP=$(awk '{print $2}' <<< "$INSTANCE_INFO")

if [[ "$INSTANCE_STATE" != "running" ]]; then
  echo "ERROR: EC2 instance is '$INSTANCE_STATE', not running."
  echo "Start the instance in the AWS Console, then run this script again."
  exit 1
fi

if [[ -z "$EC2_PUBLIC_IP" || "$EC2_PUBLIC_IP" == "None" ]]; then
  echo "ERROR: EC2 has no public IPv4 address."
  exit 1
fi

echo "EC2 public IP: $EC2_PUBLIC_IP"

echo
echo "Discovering laptop public IP..."

LAPTOP_PUBLIC_IP=$(curl -4 -fsS --max-time 10 https://checkip.amazonaws.com)
LAPTOP_PUBLIC_IP=$(tr -d '[:space:]' <<< "$LAPTOP_PUBLIC_IP")

if [[ ! "$LAPTOP_PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Could not determine a valid laptop public IP."
  exit 1
fi

echo "Laptop public IP: $LAPTOP_PUBLIC_IP"

echo
echo "Checking current SSH rule..."

aws ec2 describe-security-groups \
  --group-ids "$SECURITY_GROUP_ID" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22` && ToPort==`22`].IpRanges[].CidrIp' \
  --output table

echo

echo
echo "Updating SSH inbound rule..."

CURRENT_SSH_CIDRS=$(aws ec2 describe-security-groups \
  --group-ids "$SECURITY_GROUP_ID" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22` && ToPort==`22`].IpRanges[].CidrIp' \
  --output text)


if ! grep -qw "$LAPTOP_PUBLIC_IP/32" <<< "$CURRENT_SSH_CIDRS"; then
  echo "Adding SSH access for laptop: $LAPTOP_PUBLIC_IP/32"

  # Add the new rule first so existing access remains during the update.
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --region "$AWS_REGION" \
    --protocol tcp \
    --port 22 \
    --cidr "$LAPTOP_PUBLIC_IP/32"
else
  echo "SSH rule already includes your laptop's public IP."
fi

# Remove old IPv4 SSH sources only after the new source is allowed.
for CIDR in $CURRENT_SSH_CIDRS; do
  if [[ "$CIDR" != "$LAPTOP_PUBLIC_IP/32" && "$CIDR" != "None" ]]; then
    echo "Removing old SSH source: $CIDR"

    aws ec2 revoke-security-group-ingress \
      --group-id "$SECURITY_GROUP_ID" \
      --region "$AWS_REGION" \
      --protocol tcp \
      --port 22 \
      --cidr "$CIDR"
  fi
done


echo
echo "Updating Ansible inventory..."

INVENTORY_FILE="ansible/inventory.ini"
TEMP_FILE=$(mktemp)

if [[ ! -f "$INVENTORY_FILE" ]]; then
  echo "ERROR: $INVENTORY_FILE was not found."
  rm -f "$TEMP_FILE"
  exit 1
fi

awk -v ip="$EC2_PUBLIC_IP" '
  /^\[app\]$/ { in_app=1; print; next }
  /^\[/ { in_app=0 }
  in_app && /^devops-app[[:space:]]+ansible_host=/ {
    print "devops-app ansible_host=" ip
    updated=1
    next
  }
  { print }
  END {
    if (!updated) {
      print "ERROR: Could not find devops-app ansible_host under [app]." > "/dev/stderr"
      exit 1
    }
  }
' "$INVENTORY_FILE" > "$TEMP_FILE" || {
  rm -f "$TEMP_FILE"
  exit 1
}

cat "$TEMP_FILE" > "$INVENTORY_FILE"
rm -f "$TEMP_FILE"

echo "Ansible inventory updated to $EC2_PUBLIC_IP."
echo

echo
echo "Waiting for SSH and Ansible to become ready..."

SSH_READY=false

for attempt in $(seq 1 30); do
  if ansible -i ansible/inventory.ini app -m ping >/dev/null 2>&1; then
    SSH_READY=true
    echo "Ansible connection is ready."
    break
  fi

  echo "Attempt $attempt/30: server not ready yet."
  sleep 10
done

if [[ "$SSH_READY" != "true" ]]; then
  echo "ERROR: Ansible connection failed after 5 minutes."
  exit 1
fi

echo
echo "Checking application health..."

APP_HEALTHY=false

for attempt in $(seq 1 30); do
  if curl -fsS --max-time 5 "http://${EC2_PUBLIC_IP}:8080/health"; then
    APP_HEALTHY=true
    echo
    echo "Application health check passed."
    break
  fi

  echo "Attempt $attempt/30: application not ready yet."
  sleep 10
done

if [[ "$APP_HEALTHY" != "true" ]]; then
  echo "ERROR: Application health check failed after 5 minutes."
  echo "Check Docker and application logs on EC2."
  exit 1
fi

echo
echo "EC2 recovery checks completed successfully."
