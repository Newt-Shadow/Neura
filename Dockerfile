# ==============================================================================
# STAGE 1: BUILDER
# ==============================================================================
FROM ghcr.io/cirruslabs/flutter:3.41.1 AS build

# Set build arguments (optional)
ARG BUILD_VERSION=1.0.0
ENV FLUTTER_Web_RENDERER=canvaskit

WORKDIR /app

# 1. Dependency Caching Layer
# Copy only pubspec files first. Docker will cache this layer if pubspec doesn't change.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 2. Copy Source Code
COPY . .

# 3. Build Web App (WASM + CanvasKit optimized)
# We accept Android licenses to prevent build blocking
RUN yes | flutter doctor --android-licenses
RUN flutter build web --release --no-tree-shake-icons


# 4. Build Android APK
RUN flutter build apk --release

# ==============================================================================
# STAGE 2: PRODUCTION SERVER (NGINX)
# ==============================================================================
FROM nginx:alpine

# Metadata
LABEL maintainer="Neuro Team"
LABEL version="1.0"
LABEL description="Neuro AI Assistant - Web & Android Host"

# 1. Install utilities for the entrypoint script (Bash for logic, iproute2 for IP detection)
RUN apk add --no-cache bash iproute2 ncurses

WORKDIR /usr/share/nginx/html

# 2. Clean default Nginx files
RUN rm -rf ./*

# 3. Copy Web Build Artifacts
COPY --from=build /app/build/web ./

# 4. Copy Android APK & Rename
COPY --from=build /app/build/app/outputs/flutter-apk/app-release.apk ./neuro.apk

# 5. Copy Custom Configurations
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# 6. Permissions & Safety
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R nginx:nginx /usr/share/nginx/html

# 7. Healthcheck (Checks if Nginx is responding)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# 8. Expose & Entry
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]