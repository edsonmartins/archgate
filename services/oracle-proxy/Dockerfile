# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN apk add --no-cache maven && mvn -q -DskipTests package

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl \
  && addgroup -S app && adduser -S -G app app
COPY --from=build /src/target/oracle-proxy-*.jar /app/app.jar
USER app
ENV PORT=9040 ORACLE_PROXY_MOCK=true
EXPOSE 9040
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/actuator/health" || exit 1
ENTRYPOINT ["java","-jar","/app/app.jar"]

