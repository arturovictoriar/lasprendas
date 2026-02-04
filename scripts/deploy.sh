#!/bin/bash
cd /root/lasprendas
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build
docker image prune -f
