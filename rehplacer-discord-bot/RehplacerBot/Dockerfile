# STAGE 1: Build the application
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app

# Copy gradle files first for Docker caching
COPY gradlew .
COPY gradle gradle
COPY build.gradle .
COPY settings.gradle .

# Ensure gradlew has execution permissions
RUN chmod +x ./gradlew

# Download dependencies (this layer is cached unless build.gradle changes)
RUN ./gradlew dependencies --no-daemon

# Copy source code and build the JAR
COPY src src
RUN ./gradlew bootJar --no-daemon

# STAGE 2: Create the runtime image
# We use a slim JRE for a tiny, secure production footprint
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Create a non-root user for security
RUN useradd -m botuser
USER botuser

# Copy the JAR from the build stage
COPY --from=build /app/build/libs/*.jar app.jar

# Spring Boot default port
EXPOSE 9980

# Run the bot
ENTRYPOINT ["java", "-jar", "app.jar"]
