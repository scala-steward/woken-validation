# Verified with http://hadolint.lukasmartinelli.ch/

FROM hbpmip/scala-base-build:1.1.0-0 as scala-build-env

ARG BINTRAY_USER
ARG BINTRAY_PASS

ENV BINTRAY_USER=$BINTRAY_USER \
    BINTRAY_PASS=$BINTRAY_PASS

# First caching layer: build.sbt and sbt configuration
COPY build.sbt /build/
RUN  mkdir -p /build/project/
COPY project/build.properties project/plugins.sbt project/.gitignore /build/project/

# Run sbt on an empty project and force it to download most of its dependencies to fill the cache
RUN sbt compile

# Second caching layer: project sources
COPY src/ /build/src/
COPY docker/ /build/docker/
COPY .git/ /build/.git/
COPY .circleci/ /build/.circleci/
COPY .*.cfg .*ignore .*.yaml .*.conf *.md *.sh *.yml *.json Dockerfile LICENSE /build/

RUN /check-sources.sh

RUN sbt test assembly

FROM hbpmip/java-base:8u151-0

MAINTAINER Ludovic Claude <ludovic.claude@chuv.ch>

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

COPY docker/run.sh /
COPY docker/config/application.conf.tmpl /opt/woken-validation/config/

RUN adduser -H -D -u 1000 woken \
    && chown -R woken:woken /opt/woken-validation

COPY --from=scala-build-env /build/target/scala-2.11/woken-validation-all.jar /opt/woken-validation/woken-validation.jar

USER woken

WORKDIR /opt/woken-validation

ENTRYPOINT ["/run.sh"]

# Health checks on http://host:8081/health
# Akka on 8082
# Spark UI on 4040
EXPOSE 8081 8082 4040

HEALTHCHECK CMD curl -v --silent http://localhost:8081/health 2>&1 | grep UP

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="hbpmip/woken-validation" \
      org.label-schema.description="An orchestration platform for Docker containers running data mining algorithms" \
      org.label-schema.url="https://github.com/LREN-CHUV/woken-validation" \
      org.label-schema.vcs-type="git" \
      org.label-schema.vcs-url="https://github.com/LREN-CHUV/woken-validation" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.version="$VERSION" \
      org.label-schema.vendor="LREN CHUV" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.docker.dockerfile="Dockerfile" \
      org.label-schema.memory-hint="2048" \
      org.label-schema.schema-version="1.0"
