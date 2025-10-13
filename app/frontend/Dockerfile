# Frontend Dockerfile for Banking Application
FROM nginx:1.25-alpine

# Install required packages
RUN apk add --no-cache curl

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy frontend application files
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/

# Create a simple service worker for PWA functionality
RUN echo 'self.addEventListener("install", event => { console.log("SW installed"); });' > /usr/share/nginx/html/sw.js

# Add favicon
RUN echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="#2563eb"/><text x="50" y="65" font-family="Arial" font-size="60" fill="white" text-anchor="middle">🏦</text></svg>' > /usr/share/nginx/html/favicon.svg

# Create health check endpoint script
RUN echo '#!/bin/sh' > /usr/local/bin/health-check.sh && \
  echo 'curl -f http://localhost/nginx-health || exit 1' >> /usr/local/bin/health-check.sh && \
  chmod +x /usr/local/bin/health-check.sh

# Create necessary nginx directories with proper permissions
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
  /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp \
  /var/cache/nginx/scgi_temp && \
  chown -R nginx:nginx /var/cache/nginx && \
  chmod -R 755 /var/cache/nginx

# Set proper permissions for web content
RUN chown -R nginx:nginx /usr/share/nginx/html && \
  chmod -R 755 /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD /usr/local/bin/health-check.sh

# Expose port
EXPOSE 80

# Labels for better container management
LABEL maintainer="DevOps Team <devops@banking.com>"
LABEL version="1.0"
LABEL description="Banking Application Frontend - Nginx with static files"

# Start nginx (run as root to create pid file, workers run as nginx)
CMD ["nginx", "-g", "daemon off;"]