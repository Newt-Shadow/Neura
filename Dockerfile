# ==============================================================================
# STAGE 1: BUILD ENVIROMENT
# We use a pre-configured image with Flutter & Android SDK to save setup time.
# ==============================================================================
FROM ghcr.io/cirruslabs/flutter:3.41.0 AS builder


# Set working directory
WORKDIR /app

# 1. Copy dependencies first to cache them
COPY pubspec.yaml pubspec.lock ./

# Get packages (clean install)
RUN flutter pub get

# 2. Copy the rest of the application code
COPY . .

# 3. Build the Android APK
# We use --release for a performance-optimized build
RUN flutter build apk --release

# ==============================================================================
# STAGE 2: RUNTIME DISTRIBUTION SERVER
# We use Nginx to serve the built APK.
# ==============================================================================
FROM nginx:alpine

# 1. Create a directory to host the download
WORKDIR /usr/share/nginx/html

# 2. Copy the built APK from the 'builder' stage
COPY --from=builder /app/build/app/outputs/flutter-apk/app-release.apk ./neuro_app.apk

# 3. Create a simple Landing Page for the Judges
RUN echo '<!DOCTYPE html>\
<html>\
<head>\
    <title>Neuro App Distribution</title>\
    <style>\
        body { font-family: sans-serif; text-align: center; padding: 50px; background: #f0f4f8; }\
        .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: inline-block; }\
        h1 { color: #009688; }\
        p { color: #555; }\
        .btn { display: inline-block; background: #009688; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 20px; }\
        .btn:hover { background: #00796b; }\
    </style>\
</head>\
<body>\
    <div class="card">\
        <h1>Neuro App Ready</h1>\
        <p>The solution has been successfully built inside this isolated environment.</p>\
        <p><strong>Note:</strong> This app uses on-device AI and Vision, so it requires an Android device.</p>\
        <a href="neuro_app.apk" class="btn" download>⬇ Download APK</a>\
    </div>\
</body>\
</html>' > index.html

# 4. Expose Port 80
EXPOSE 80

# 5. Start Nginx
CMD ["nginx", "-g", "daemon off;"]