FROM alpine:3.21 AS builder

WORKDIR /build

RUN mkdir -p /build/html && \
    echo '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Secure Supply Chain MVP</title></head><body><h1>✅ Secure Container</h1><p>This image passed all security gates.</p></body></html>' > /build/html/index.html

FROM nginx:1.27-alpine3.21

LABEL org.opencontainers.image.title="Secure Supply Chain MVP" \
    org.opencontainers.image.description="Demonstration of secure container build pipeline" \
    org.opencontainers.image.vendor="RASP Cyber Academy" \
    org.opencontainers.image.source="https://github.com/r4nol/secure-supply-chain"

RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

COPY --from=builder /build/html /usr/share/nginx/html

RUN printf 'server {\n\
    listen 80;\n\
    server_name localhost;\n\
    root /usr/share/nginx/html;\n\
    \n\
    # Security headers - defense in depth\n\
    add_header X-Frame-Options "DENY" always;\n\
    add_header X-Content-Type-Options "nosniff" always;\n\
    add_header X-XSS-Protection "1; mode=block" always;\n\
    add_header Content-Security-Policy "default-src '\''self'\''" always;\n\
    \n\
    # Disable server version disclosure\n\
    server_tokens off;\n\
    \n\
    location / {\n\
    try_files $uri $uri/ =404;\n\
    }\n\
    }\n' > /etc/nginx/conf.d/default.conf && \
    # Create cache directories and set permissions for non-root user
    mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    # Fix PID file location for non-root
    sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf && \
    touch /tmp/nginx.pid && \
    chown nginx:nginx /tmp/nginx.pid

USER nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1
