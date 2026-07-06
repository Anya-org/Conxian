#!/bin/bash
# Setup script for Conxian Sandbox devcontainer

set -e

echo "🔧 Setting up Conxian Sandbox..."

# Install pnpm if not present
if ! command -v pnpm &> /dev/null; then
    echo "📦 Installing pnpm..."
    npm install -g pnpm
fi

# Install dependencies
echo "📦 Installing dependencies..."
pnpm install

# Start infrastructure
echo "🚀 Starting Docker services..."
docker-compose up -d db redis

# Wait for services to be ready
echo "⏳ Waiting for services..."
sleep 5

# Copy environment file
if [ ! -f .env ]; then
    echo "📝 Creating .env from example..."
    cp .env.example .env
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Run 'pnpm run example:hello-world' to get started."
echo "Visit http://localhost:3000 for Gateway docs."
