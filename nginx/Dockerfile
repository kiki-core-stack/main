FROM alpine:latest

# Install packages
RUN apk update && apk upgrade --no-cache
RUN apk add -lu --no-cache brotli nginx nginx-mod-http-brotli

# Copy configs
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./public /etc/nginx/public
COPY ./servers /etc/nginx/servers

# Set cmd
CMD ["nginx", "-g", "daemon off;"]
