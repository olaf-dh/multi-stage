FROM composer:2

# Install CA-Certificate for base (Alpine/Debian)
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache ca-certificates && update-ca-certificates; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && apt-get install -y --no-install-recommends ca-certificates && update-ca-certificates && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "WARN: Unknown base; please install CA certs manually"; \
    fi
