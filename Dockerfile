# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t ip-tracker .
# docker run -d -p 3000:3000 --name ip-tracker ip-tracker

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and .tool-versions
ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# App lives here
WORKDIR /app

# Install base packages: curl for healthchecks, libpq5 for PostgreSQL, libjemalloc2 for memory
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RACK_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Ensure the entrypoint is executable
RUN chmod +x bin/docker-entrypoint

# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 app && \
    useradd app --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=app:app --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=app:app --from=build /app /app

# Entrypoint migrates the database.
ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the app server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
