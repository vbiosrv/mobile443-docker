#!/usr/bin/env bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Конфигурация
DOCKER_HUB_USER="vbiosrv"
IMAGE_NAME="mobile443-docker"
VERSION="1.0.0"

echo -e "${GREEN}=== Сборка Docker образа ===${NC}"

# Сборка образа
docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest .
docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${VERSION} .

echo -e "${GREEN}=== Проверка образов ===${NC}"
docker images | grep ${IMAGE_NAME}

echo -e "${YELLOW}=== Вход в Docker Hub ===${NC}"
docker login

echo -e "${GREEN}=== Публикация образов ===${NC}"
docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest
docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${VERSION}

echo -e "${GREEN}=== Готово! ===${NC}"
echo "Образ опубликован: https://hub.docker.com/r/${DOCKER_HUB_USER}/${IMAGE_NAME}"
