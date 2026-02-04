#!/bin/bash
cd /root/lasprendas/backend
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build
docker image prune -f
