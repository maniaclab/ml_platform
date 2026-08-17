# ml_platform

Machine learning platform with Python 3.12, TensorFlow, Keras, ROOT, Jupyter, and HEP tools. Docker image repository for the MaNIAC Lab ML platform using Pixi for dependency management and GitHub Actions CI/CD.

## Two Images: GPU and CPU

This project ships **two separate images**, built from the same `Dockerfile` and `pixi.toml` but with
different base images and pixi environments:

| Image | Base image | Pixi environment | Use when |
|---|---|---|---|
| `ml-platform-gpu` | `ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0` (Ubuntu 24.04 + CUDA 13.0) | `ml` (TensorFlow GPU) | Running on a node with a compatible NVIDIA GPU/driver |
| `ml-platform-cpu` | `ghcr.io/prefix-dev/pixi:noble` (Ubuntu 24.04, no CUDA) | `mlcpu` (TensorFlow CPU) | Running anywhere else |

The CPU image intentionally does **not** use a CUDA base image, even though CUDA packages aren't
installed into its pixi environment: CUDA base images bake `NVIDIA_REQUIRE_CUDA` into `ENV`, which
container runtimes configured with `default-runtime: nvidia` enforce as a driver-version check on
every container — even ones that never request a GPU. Building the CPU image from a plain base avoids
that failure mode entirely, rather than working around it after the fact.

Pick the image that matches where you're deploying; there is no runtime GPU-detection or environment
switching inside either image.

**Available registries** (each image is pushed to all three, with a `-gpu`/`-cpu` suffix):
- `ghcr.io/maniaclab/ml-platform-gpu` / `ghcr.io/maniaclab/ml-platform-cpu`
- `docker.io/ivukotic/ml_platform-gpu` / `docker.io/ivukotic/ml_platform-cpu`
- `hub.opensciencegrid.org/usatlas/ml-platform-gpu` / `hub.opensciencegrid.org/usatlas/ml-platform-cpu`

**Platforms:** linux/amd64

## Pull Image

```bash
# From GitHub Container Registry
docker pull ghcr.io/maniaclab/ml-platform-gpu:latest
docker pull ghcr.io/maniaclab/ml-platform-cpu:latest

# From Docker Hub
docker pull ivukotic/ml_platform-gpu:latest
docker pull ivukotic/ml_platform-cpu:latest

# From OSG Harbor
docker pull hub.opensciencegrid.org/usatlas/ml-platform-gpu:latest
docker pull hub.opensciencegrid.org/usatlas/ml-platform-cpu:latest
```

## Usage

### Run Interactive Shell

```bash
docker run --rm -it ghcr.io/maniaclab/ml-platform-cpu:latest bash
```

### Run Jupyter Lab

```bash
docker run --rm -p 9999:9999 ghcr.io/maniaclab/ml-platform-cpu:latest jupyter lab --ip=0.0.0.0 --port=9999
```

Then open http://localhost:9999 in your browser.

### Run with GPU Support

```bash
docker run --rm --gpus all -it ghcr.io/maniaclab/ml-platform-gpu:latest python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

### Mount Data Volume

```bash
docker run --rm -v /path/to/data:/data -it ghcr.io/maniaclab/ml-platform-cpu:latest bash
```

### Singularity/Apptainer

```bash
singularity pull docker://ghcr.io/maniaclab/ml-platform-cpu:latest
singularity run ml-platform-cpu_latest.sif python --version
```

## Dependencies

All dependencies are managed via Pixi (conda-forge + PyPI). See [`pixi.toml`](pixi.toml) for the complete list and version constraints.

**Highlights:**
- Python 3.12, ROOT 6.32+, OpenJDK 8
- ML frameworks: TensorFlow, Keras, scikit-learn
- Data science: NumPy, Pandas, SciPy, PyArrow, HDF5
- Jupyter ecosystem: JupyterLab, ipywidgets, jupyterlab-git, RISE
- HEP tools: uproot, atlasify, rucio-jupyterlab
- Visualization: Matplotlib, Seaborn, Bokeh

## Features

### Pixi Environment

All packages are managed via Pixi and activated automatically via the entrypoint. No need to source activation scripts.

Each image bakes in exactly one pixi environment (`ml` for `ml-platform-gpu`, `mlcpu` for
`ml-platform-cpu`), both built from the same shared `mlbase` dependency set. `/app/entrypoint.sh` is
just the `pixi shell-hook` output for that one environment — there is no runtime detection or
switching. `PIXI_KERNEL_DEFAULT_ENVIRONMENT` is baked in too, so notebook kernels default correctly.

### Jupyter Configuration

- Binds to `0.0.0.0:9999` by default
- Password change disabled (for container security)
- Browser auto-open disabled

### GPU Support

- `ml-platform-gpu` uses a CUDA 13.0 base image and TensorFlow compiled with GPU support
- `ml-platform-cpu` uses a plain (non-CUDA) base image and plain CPU TensorFlow — it has no
  `NVIDIA_REQUIRE_CUDA` baked in, so it runs cleanly on any host regardless of driver version
- Singularity/Apptainer GPU driver compatibility via `/host-libs/` mount (GPU image)

### User Management

Includes `sync_users_debian.sh` for MaNIAC Lab user synchronization infrastructure and `SetupPrivateJupyterLab.sh` for setting up private JupyterLab instances.

## Architecture

### Pixi-based Dependency Management

All dependencies (system packages, Python libraries, compilers, ROOT) are managed via [Pixi](https://pixi.sh/) and conda-forge, replacing traditional `apt-get` + `pip venv` workflows.

**Benefits:**
- Reproducible environments via `pixi.lock`
- Unified dependency resolution (no apt/pip conflicts)
- Binary packages from conda-forge (faster builds)
- Cross-platform lock files (Linux + macOS for development)

### Multi-Stage Docker Build

A single `Dockerfile`, parameterized by `BASE_IMAGE` and `PIXI_ENVIRONMENT` build-args, produces both
images:

```dockerfile
ARG BASE_IMAGE="ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0"
ARG PIXI_ENVIRONMENT="ml"

# Stage 1: Build - install the requested environment via pixi, generate its activation script
FROM ${BASE_IMAGE} AS build
RUN pixi install --locked --environment $PIXI_ENVIRONMENT
# pixi shell-hook output -> /app/entrypoint.sh

# Stage 2: Final - copy just that one environment
FROM ${BASE_IMAGE} AS final
COPY --from=build /app/.pixi/envs/$PIXI_ENVIRONMENT /app/.pixi/envs/$PIXI_ENVIRONMENT
COPY --from=build /app/entrypoint.sh /app/entrypoint.sh
```

```bash
# GPU image
docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
  --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu .

# CPU image
docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
  --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu .
```

**Key Points:**
- `/app/entrypoint.sh` is plain `pixi shell-hook` output — no dispatching, no runtime GPU detection
- The generated script also exports `PIXI_KERNEL_DEFAULT_ENVIRONMENT` so notebook kernels default
  to the environment actually shipped in the image
- All RUN commands in the final stage use `/app/entrypoint.sh` to activate the environment
- Singularity/Apptainer compatible via `/host-libs/` mount point (GPU image)

### CI/CD Workflow

The workflow builds and pushes **both** images on every trigger, via a 2-entry build matrix
(`gpu`/`cpu`):

**Triggers:**
- **Push to `main`:** Build both images → push each with tags `latest`, `sha-abc1234`
- **Git tag `v*`:** Build both images → push each with tags `X.Y.Z`, `X.Y`, `sha-abc1234`
- **Pull request:** Build both images (no push, validation only)
- **Manual:** `workflow_dispatch` builds and pushes both images

**Tag behavior** (identical for `ml-platform-gpu` and `ml-platform-cpu`):

| Trigger | Tags |
|---------|------|
| Push to `main` | `latest`, `sha-abc1234` |
| Git tag `v2026.2.11` | `2026.2.11`, `2026.2`, `sha-abc1234` |
| Pull request | `sha-abc1234` (no push) |

**Multi-Registry Push:**
Authenticated via GitHub secrets:
- `GITHUB_TOKEN` (automatic) for ghcr.io
- `DOCKER_USERNAME` / `DOCKER_PASSWORD` for docker.io
- `OSG_HARBOR_ROBOT_USER` / `OSG_HARBOR_ROBOT_PASSWORD` for OSG Harbor

## Development

### Modifying Dependencies

1. Edit `pixi.toml`
2. Regenerate lock file:
   ```bash
   CONDA_OVERRIDE_CUDA=12.6 pixi install
   ```
3. Test locally (both images):
   ```bash
   docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
     --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
   docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
     --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .
   ```
4. Commit both files:
   ```bash
   git add pixi.toml pixi.lock
   git commit -m "chore: update dependencies"
   ```

### Testing Locally

```bash
# Build both images
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
  --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
  --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .

# Test Python
docker run --rm ml-platform-cpu:test python --version

# Test ML packages
docker run --rm ml-platform-cpu:test python -c "import tensorflow, keras, numpy, pandas; print('OK')"

# Test ROOT
docker run --rm ml-platform-cpu:test root --version

# Test Jupyter
docker run --rm ml-platform-cpu:test jupyter --version

# Test HEP tools
docker run --rm ml-platform-cpu:test python -c "import uproot, atlasify; print('OK')"

# Repeat against ml-platform-gpu:test, ideally with --gpus all on a GPU host
```

### Releasing a Version

This repository uses **CalVer** (Calendar Versioning) with the format `YYYY.M.D` (year, month, day).

**Example:**

```bash
# Create annotated tag with CalVer format
git tag -a v2026.2.11 -m "Initial consolidated release with Pixi

  - Merged ml_base and ml_platform
  - All dependencies via conda-forge + PyPI
  - CUDA 13.0 support
  - Python 3.12, ROOT 6.32+"

# Push tag to trigger CI build
git push origin v2026.2.11
```

**Important:** Use the current date without leading zeros (e.g., `2.19` not `02.19`, `9.5` not `09.05`).

This triggers a full build with Docker tags:
- `2026.2.11` (full CalVer)
- `2026.2` (year-month)
- `sha-abc1234` (commit SHA)

## Maintenance

### Updating Base Image

The base images (`ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0` for GPU, `ghcr.io/prefix-dev/pixi:noble`
for CPU) should be updated periodically:

1. Check for newer versions: https://github.com/prefix-dev/pixi-docker/pkgs/container/pixi
2. Update the `ARG BASE_IMAGE` default in `Dockerfile`, and the matching `base_image` value in
   `.github/workflows/build-images.yaml`'s matrix — for whichever variant(s) changed
3. Test both images locally
4. Commit and push

### Updating Dependencies

Pixi automatically resolves the latest compatible versions unless pinned. To update:

```bash
# Update pixi.toml with new version constraints
vim pixi.toml

# Regenerate lock file
CONDA_OVERRIDE_CUDA=12.6 pixi install

# Test both images
docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
  --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
docker build --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
  --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .

# Commit both files
git add pixi.toml pixi.lock
git commit -m "chore: update dependencies"
```

### Monitoring Builds

- **GitHub Actions:** https://github.com/maniaclab/ml_platform/actions
- **ghcr.io:** https://github.com/orgs/maniaclab/packages
- **OSG Harbor:** https://hub.opensciencegrid.org/harbor/projects

## Troubleshooting

### Pixi Installation Fails in Docker

**Error:** `Package not found` or dependency resolution fails

**Solution:** Check that:
1. Package exists on conda-forge: https://anaconda.org/conda-forge/<package>
2. Platform is `linux-64` (not `noarch` or `osx-arm64` only)
3. Move to `[pypi-dependencies]` if not on conda-forge

### Build Fails with "curl: not found"

**Error:** `/bin/sh: 1: curl: not found`

**Solution:** Prefix commands with entrypoint to activate environment:
```dockerfile
# Wrong
RUN curl -O https://example.com/file

# Correct
RUN /app/entrypoint.sh curl -O https://example.com/file
```

### Image Size Too Large

**Symptoms:** Image > 5GB

**Solutions:**
1. Use multi-stage build (already implemented)
2. Remove unused dependencies from `pixi.toml`
3. Add packages to `.pixi/.condapackageignore` to exclude caches
4. Use `--no-cache-dir` for pip in `[pypi-dependencies]`

### Import Errors

If you get `ModuleNotFoundError`, ensure the package is in `pixi.toml`:
- Check if package exists on conda-forge: https://anaconda.org/conda-forge/<package>
- If not, add to `[pypi-dependencies]` section instead

### GPU Not Detected

Make sure you pulled `ml-platform-gpu`, not `ml-platform-cpu` — the CPU image has no GPU support at all
by design.

```bash
# Check CUDA is visible
docker run --rm --gpus all ghcr.io/maniaclab/ml-platform-gpu:latest nvidia-smi

# Check TensorFlow GPU support
docker run --rm --gpus all ghcr.io/maniaclab/ml-platform-gpu:latest python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

### Singularity GPU Issues

Ensure `/host-libs/` is bound to host driver paths:
```bash
singularity run --nv --bind /usr/lib/x86_64-linux-gnu:/host-libs ml-platform-gpu_latest.sif
```

## References

- **Pixi Documentation:** https://pixi.sh/
- **Matthew Feickert's SciPy 2024 Proceedings:** Pixi multi-stage Docker pattern
- **GitHub Actions:** https://docs.github.com/en/actions
- **Docker Build Push Action:** https://github.com/docker/build-push-action
- **TensorFlow GPU Support:** https://www.tensorflow.org/install/gpu
- **ROOT Documentation:** https://root.cern/
- **JupyterLab Documentation:** https://jupyterlab.readthedocs.io/
- **Singularity GPU Support:** https://github.com/singularityware/singularity/issues/611

## License

MIT License
