#
# baseimage Dockerfile
#
# https://github.com/jlesage/docker-baseimage
#

ARG BASEIMAGE=unknown

ARG ALPINE_PKGS="\
    # For timezone support
    tzdata \
    # For 'groupmod' command
    shadow \
"

ARG DEBIAN_PKGS="\
    # For timezone support
    tzdata \
"

# Build the init system and process supervisor.
FROM alpine:3.14 AS cinit
COPY src/cinit /tmp/cinit
RUN apk --no-cache add build-base
RUN make -C /tmp/cinit

# Build the log monitor.
FROM alpine:3.14 AS logmonitor
COPY src/logmonitor /tmp/logmonitor
RUN apk --no-cache add build-base linux-headers
RUN make -C /tmp/logmonitor

# Build su-exec
FROM alpine:3.14 AS su-exec
RUN apk --no-cache add build-base curl
RUN mkdir /tmp/su-exec
RUN curl -# -L https://github.com/ncopa/su-exec/archive/v0.2.tar.gz | tar xz --strip 1 -C /tmp/su-exec
RUN make -C /tmp/su-exec su-exec-static
RUN strip /tmp/su-exec/su-exec-static

# Pull base image.
FROM ${BASEIMAGE}

# Define working directory.
WORKDIR /tmp

# Copy helpers.
COPY helpers/* /usr/bin/

# Install the init system and process supervisor.
COPY --from=cinit /tmp/cinit/cinit /usr/sbin/

# Install the log monitor.
COPY --from=logmonitor /tmp/logmonitor/logmonitor /usr/bin/

# Install su-exec.
COPY --from=su-exec /tmp/su-exec/su-exec-static /usr/sbin/su-exec

# Install system packages.
ARG ALPINE_PKGS
ARG DEBIAN_PKGS
RUN \
    if [ -n "$(which apk)" ]; then \
        add-pkg ${ALPINE_PKGS}; \
    else \
        add-pkg ${DEBIAN_PKGS}; \
    fi

# Make sure all required directory exists.
RUN \
    mkdir -p \
        /defaults \
        /etc/cont-init.d \
        /etc/cont-finish.d \
        /etc/services.d \
        /etc/cont-env.d

# Add files.
COPY rootfs/ /

# Set environment variables.
ENV \
    USER_ID=1000 \
    GROUP_ID=1000 \
    SUP_GROUP_IDS= \
    UMASK=022 \
    TZ=Etc/UTC \
    KEEP_APP_RUNNING=0 \
    APP_NICENESS=0

# Define mountable directories.
VOLUME ["/config"]

# Define default command.
# Use the init system.
CMD ["/init"]

# Metadata.
ARG IMAGE_VERSION=unknown
LABEL \
      org.label-schema.name="baseimage" \
      org.label-schema.description="A minimal docker baseimage to ease creation of long-lived application containers" \
      org.label-schema.version="${IMAGE_VERSION}" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-baseimage" \
      org.label-schema.schema-version="1.0"
