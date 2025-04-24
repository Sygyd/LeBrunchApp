FROM debian:bullseye-slim AS build

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    libglu1-mesa \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set up Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"
RUN flutter channel stable && flutter upgrade && flutter config --enable-web

# Copy the Flutter project
WORKDIR /app
COPY . .

# Create an empty .env file if it doesn't exist
RUN touch .env

# Build the Flutter web app
RUN flutter pub get
RUN flutter build web --release

# Production stage
FROM nginx:alpine

# Copy the built files to nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy a custom Nginx configuration if needed
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose the Nginx port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 