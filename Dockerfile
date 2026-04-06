# ---- Build Stage ----
FROM dhi.io/eclipse-temurin:21-jdk-debian13-dev AS builder

WORKDIR /app

# Cache Gradle wrapper and dependencies before copying source
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle

RUN ./gradlew dependencies --no-daemon -q

COPY src ./src

RUN ./gradlew bootJar --no-daemon -q && \
    java -Djarmode=layertools -jar build/libs/*.jar extract --destination build/extracted

# ---- Runtime Stage ----
# FROM dhi.io/eclipse-temurin:21-debian13 AS runtime  # DHI hardened: CIS-compliant, nonroot, no shell — 28 LOW, 13 MEDIUM CVEs
FROM eclipse-temurin:21-jre-noble AS runtime

WORKDIR /app

# Copy layered JAR contents in order of least-to-most frequently changed
COPY --from=builder /app/build/extracted/dependencies ./
COPY --from=builder /app/build/extracted/spring-boot-loader ./
COPY --from=builder /app/build/extracted/snapshot-dependencies ./
COPY --from=builder /app/build/extracted/application ./

EXPOSE 8080

ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "org.springframework.boot.loader.launch.JarLauncher"]
