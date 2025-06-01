# Stage 1: Build the Flutter Web App
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve the app using NGINX
FROM nginx:alpine

# Copy the built web app from the previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]