# docker build -t localconfig .

IMAGE_NAME=$(uuidgen | awk '{print tolower($0)}')
docker build -t ttl.sh/${IMAGE_NAME}:24h .
docker push ttl.sh/${IMAGE_NAME}:24h
