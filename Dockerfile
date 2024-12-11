# Build stage
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV LUAROCKS_VERSION=3.8.0
ENV OPENSSL_SUPPRESS_DEPRECATED=1

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    lua5.3 \
    liblua5.3-dev \
    python3 \
    python3-pip \
    python3-venv \
    libssl-dev \
    zlib1g-dev \
    libsqlite3-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install LuaRocks
RUN wget https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz \
    && tar zxpf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${LUAROCKS_VERSION} \
    && ./configure --lua-version=5.3 --with-lua-include=/usr/include/lua5.3 \
    && make && make install \
    && cd .. \
    && rm -rf luarocks-${LUAROCKS_VERSION}.tar.gz luarocks-${LUAROCKS_VERSION}

# Install Lua dependencies
RUN luarocks install basexx 0.4.1 && \
    luarocks install lpeg 1.1.0 && \
    luarocks install lpeg_patterns 0.5 && \
    luarocks install binaryheap 0.4 && \
    luarocks install fifo 0.2 && \
    luarocks install http 0.4 && \
    luarocks install dkjson 2.5 && \
    luarocks install luasql-sqlite3 2.6.0 && \
    luarocks install luafilesystem 1.8.0 && \
    luarocks install luasocket && \
    luarocks install lua-cjson 2.1.0

# Setup Python virtual environment and install dependencies
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY python_src/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Final stage
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/venv/bin:$PATH"
ENV LUA_PATH="/usr/local/share/lua/5.3/?.lua;/usr/local/share/lua/5.3/?/init.lua;./?.lua"
ENV LUA_CPATH="/usr/local/lib/lua/5.3/?.so;/usr/local/lib/lua/5.3/?/init.so;./?.so"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    lua5.3 \
    python3 \
    python3-venv \
    libsqlite3-0 \
    libssl3 \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy Python virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy Lua dependencies from builder
COPY --from=builder /usr/local/lib/lua /usr/local/lib/lua
COPY --from=builder /usr/local/share/lua /usr/local/share/lua

# Create necessary directories
RUN mkdir -p /app/logs /app/data /app/backup /app/images/{input,output,temp} /app/models

# Create non-root user
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app

WORKDIR /app
COPY --chown=appuser:appuser ./sql /app/sql

# Copy application files
COPY --chown=appuser:appuser . /app

# Set up entrypoint script
COPY --chown=appuser:appuser entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD lua /app/lua-scripts/healthcheck.lua || exit 1

# Expose ports
EXPOSE 7860 8080 9090

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["lua", "/app/lua-scripts/pipeline.lua"]
