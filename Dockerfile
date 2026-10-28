# Using uv for fast Python package management
FROM python:3.14-slim-bookworm as python-base

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    UV_VERSION=0.13.6 \
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv" \
    XDG_CACHE_HOME="/app/.cache"

ENV PATH="$VENV_PATH/bin:$PATH"

RUN addgroup --gid 1000 --system app \
    && adduser --uid 1000 --system --no-create-home --shell=/bin/false --disabled-password --group app \
    && mkdir /app \
    && chown -R 1000:1000 /app

RUN apt-get update && \
apt-get install --no-install-recommends -y \
    make \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install --no-cache-dir uv==$UV_VERSION

# `builder-base` stage is used to build deps + create our virtual environment
FROM python-base as builder-base
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        build-essential

WORKDIR $PYSETUP_PATH
COPY pyproject.toml uv.lock* ./

# Install runtime dependencies using uv
RUN uv sync --no-dev


# `development` image is used during development / testing
FROM python-base as development
ENV ENVIRONMENT=development \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR $PYSETUP_PATH

# Copy in our built venv
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH

# Install all dependencies including dev
RUN uv sync

# Will become mountpoint of our code
WORKDIR /app

USER app

EXPOSE 8000


# `production` image used for runtime
FROM python-base as production
ENV ENVIRONMENT=production
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH
COPY --chown=app:app . /app/
WORKDIR /app

USER app
