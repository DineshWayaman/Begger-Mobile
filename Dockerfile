# Use official Flutter image or a lightweight base
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Build Flutter web app
RUN flutter pub get
RUN flutter build web --release

# Expose port 80
EXPOSE 3002