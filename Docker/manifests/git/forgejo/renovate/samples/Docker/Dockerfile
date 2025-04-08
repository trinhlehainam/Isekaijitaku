# Multi-stage build example to test Renovate's Docker image update capabilities
# Base image for building
FROM node:18.19.1-alpine AS builder

WORKDIR /app

# Install development dependencies
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy application code
COPY . .
RUN npm run build

# Production image
FROM nginx:1.25.4-alpine

# Use specific versions of utilities
RUN apk add --no-cache curl=8.5.0-r0 jq=1.7.1-r0

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]