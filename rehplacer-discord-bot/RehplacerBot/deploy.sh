#!/bin/bash

# $1 refers to the first argument passed to the script (e.g., pi@192.168.1.10)
REMOTE_HOST=$1
REMOTE_PATH="~/code/RehplacerBot"

# 1. Validation
if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 user@hostname"
    exit 1
fi

# 2. Build for ARM64 (Linux)
echo "🚀 Building the docker image for ARM64..."
docker build --platform linux/arm64 -t rehplacer-bot:latest .

# 3. Stream to Pi
echo "📦 Saving, compressing, and streaming to $REMOTE_HOST..."
docker save rehplacer-bot:latest | gzip | ssh "$REMOTE_HOST" "gunzip | docker load"

# 4. Prepare Remote Directory
echo "📁 Ensuring remote directory exists..."
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_PATH"

# 5. Send Configuration Files
echo "🔐 Sending .env and docker-compose.yml..."
scp .env "$REMOTE_HOST:$REMOTE_PATH/.env"
scp docker-compose.yml "$REMOTE_HOST:$REMOTE_PATH/docker-compose.yml"

# 6. Restart Service
echo "🔄 Restarting the bot on the Pi..."
ssh "$REMOTE_HOST" "sudo systemctl restart rehdiscordbot"

echo "⏳ Waiting 3 seconds for bot to initialize..."
sleep 3
ssh "$REMOTE_HOST" "journalctl CONTAINER_TAG=discord-bot-rehplacer -n 20 --no-pager"

echo "✅ Deployment complete!"
