ARG BASE_IMAGE="ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0"
ARG CUDA_VERSION="12.8"
ARG PIXI_ENVIRONMENT="ml"

# ============================================================
# Stage 1: Build - install dependencies via pixi
# ============================================================
FROM ${BASE_IMAGE} AS build

ARG CUDA_VERSION
ARG PIXI_ENVIRONMENT

WORKDIR /app
COPY pixi.toml pixi.lock ./
ENV CONDA_OVERRIDE_CUDA=$CUDA_VERSION
RUN pixi install --manifest-path /app/pixi.toml --locked --environment $PIXI_ENVIRONMENT

# Generate entrypoint from pixi shell-hook
RUN echo "#!/bin/bash" > /app/entrypoint.sh && \
    echo "export PYTHONNOUSERSITE=1" >> /app/entrypoint.sh && \
    echo "JUPYTER_CONFIG_DIR=/app/.jupyter/config" >> /app/entrypoint.sh && \
    echo "JUPYTER_DATA_DIR=/app/.jupyter/data" >> /app/entrypoint.sh && \
    echo "JUPYTER_RUNTIME_DIR=/app/.jupyter/runtime" >> /app/entrypoint.sh && \
    pixi shell-hook --manifest-path /app/pixi.toml \
                    --environment $PIXI_ENVIRONMENT -s bash >> /app/entrypoint.sh && \
    echo 'export PIXI_KERNEL_DEFAULT_ENVIRONMENT="$PIXI_ENVIRONMENT_NAME"' >> /app/entrypoint.sh && \
    echo 'exec "$@"' >> /app/entrypoint.sh

# ============================================================
# Stage 2: Final runtime image
# ============================================================
FROM ${BASE_IMAGE} AS final

ARG PIXI_ENVIRONMENT

WORKDIR /app

# Copy pixi environment (the only large layer)
COPY --from=build --chmod=0777 /app/.pixi/envs/$PIXI_ENVIRONMENT /app/.pixi/envs/$PIXI_ENVIRONMENT
COPY --from=build /app/pixi.toml /app/pixi.toml
COPY --from=build /app/pixi.lock /app/pixi.lock
COPY --from=build /app/.pixi/.gitignore /app/.pixi/.gitignore
COPY --from=build /app/.pixi/.condapackageignore /app/.pixi/.condapackageignore
COPY --from=build --chmod=0755 /app/entrypoint.sh /app/entrypoint.sh
# Jupyter configuration
COPY config/jupyter_notebook_config.py /usr/local/etc/jupyter_notebook_config.py
COPY --chmod=0755 config/SetupPrivateJupyterLab.sh /usr/local/bin/SetupPrivateJupyterLab.sh

# Singularity/Apptainer host GPU driver compatibility
# see https://github.com/singularityware/singularity/issues/611
RUN mkdir -p /host-libs && \
    echo "/host-libs/" > /etc/ld.so.conf.d/000-host-libs.conf && \
    ldconfig

# Workspace directory
RUN mkdir -p /workspace
# match jupyter configuration
RUN mkdir -p /app/.jupyter/{config,data,runtime} && \
    chmod -R a+rwx /app/.jupyter && \
    chmod 0777 /app/.pixi && \
    chmod a+rwx /app/pixi.toml /app/pixi.lock

# User sync script (MaNIAC Lab infrastructure)
RUN /app/entrypoint.sh curl -fsSL -o /usr/local/bin/sync_users_debian.sh \
    https://raw.githubusercontent.com/maniaclab/ci-connect-api/master/resources/provisioner/sync_users_debian.sh && \
    chmod +x /usr/local/bin/sync_users_debian.sh

# Disable user site-packages
ENV PYTHONNOUSERSITE=1
# Force Jupyter to ignore user dirs
ENV JUPYTER_CONFIG_DIR=/app/.jupyter/config
ENV JUPYTER_DATA_DIR=/app/.jupyter/data
ENV JUPYTER_RUNTIME_DIR=/app/.jupyter/runtime
# Prevent pixi from touching pixi.lock/repodata at runtime
ENV PIXI_FROZEN=true

ENTRYPOINT ["/app/entrypoint.sh"]
