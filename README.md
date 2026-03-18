# ml_platform

Machine learning platform with Python 3.12, TensorFlow, Keras, ROOT, Jupyter, and HEP tools. Docker image repository for the MaNIAC Lab ML platform using Pixi for dependency management and GitHub Actions CI/CD.

## Registries

**Available registries:**
- `ghcr.io/maniaclab/ml-platform`
- `docker.io/ivukotic/ml_platform`
- `hub.opensciencegrid.org/usatlas/ml-platform`

**Base:** `ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0` (Ubuntu 24.04 + CUDA 13.0)

**Platforms:** linux/amd64

## Pull Image

```bash
# From GitHub Container Registry
docker pull ghcr.io/maniaclab/ml-platform:latest

# From Docker Hub
docker pull ivukotic/ml_platform:latest

# From OSG Harbor
docker pull hub.opensciencegrid.org/usatlas/ml-platform:latest
```

## Usage

### Run Interactive Shell

```bash
docker run --rm -it ghcr.io/maniaclab/ml-platform:latest bash
```

### Run Jupyter Lab

```bash
docker run --rm -p 9999:9999 ghcr.io/maniaclab/ml-platform:latest jupyter lab --ip=0.0.0.0 --port=9999
```

Then open http://localhost:9999 in your browser.

### Run with GPU Support

```bash
docker run --rm --gpus all -it ghcr.io/maniaclab/ml-platform:latest python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

### Mount Data Volume

```bash
docker run --rm -v /path/to/data:/data -it ghcr.io/maniaclab/ml-platform:latest bash
```

### Singularity/Apptainer

```bash
singularity pull docker://ghcr.io/maniaclab/ml-platform:latest
singularity run ml-platform_main.sif python --version
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

### Jupyter Configuration

- Binds to `0.0.0.0:9999` by default
- Password change disabled (for container security)
- Browser auto-open disabled

### GPU Support

- CUDA 13.0 base image
- Singularity/Apptainer GPU driver compatibility via `/host-libs/` mount
- TensorFlow compiled with GPU support

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

```dockerfile
# Stage 1: Build - install dependencies via pixi
FROM ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 AS build
RUN pixi install --locked
RUN pixi shell-hook > entrypoint.sh

# Stage 2: Final - copy environment only
FROM ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 AS final
COPY --from=build /app/.pixi/envs/default /app/.pixi/envs/default
COPY --from=build /app/entrypoint.sh /app/entrypoint.sh
```

**Key Points:**
- Pixi shell-hook generates entrypoint that activates environment
- All RUN commands in final stage use `/app/entrypoint.sh` prefix
- Singularity/Apptainer compatible via `/host-libs/` mount point

### CI/CD Workflow

The workflow builds and pushes the image on every trigger:

**Triggers:**
- **Push to `main`:** Build image → push with tags `latest`, `sha-abc1234`
- **Git tag `v*`:** Build image → push with tags `X.Y.Z`, `X.Y`, `sha-abc1234`
- **Pull request:** Build image (no push, validation only)
- **Manual:** `workflow_dispatch` builds and pushes image

**Tag behavior:**

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
3. Test locally:
   ```bash
   docker build -t ml-platform:test .
   ```
4. Commit both files:
   ```bash
   git add pixi.toml pixi.lock
   git commit -m "chore: update dependencies"
   ```

### Testing Locally

```bash
# Build
docker build --platform linux/amd64 -t ml-platform:test .

# Test Python
docker run --rm ml-platform:test python --version

# Test ML packages
docker run --rm ml-platform:test python -c "import tensorflow, keras, numpy, pandas; print('OK')"

# Test ROOT
docker run --rm ml-platform:test root --version

# Test Jupyter
docker run --rm ml-platform:test jupyter --version

# Test HEP tools
docker run --rm ml-platform:test python -c "import uproot, atlasify; print('OK')"
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

The base image `ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0` should be updated periodically:

1. Check for newer versions: https://github.com/prefix-dev/pixi-docker/pkgs/container/pixi
2. Update `FROM` lines in Dockerfile
3. Test locally
4. Commit and push

### Updating Dependencies

Pixi automatically resolves the latest compatible versions unless pinned. To update:

```bash
# Update pixi.toml with new version constraints
vim pixi.toml

# Regenerate lock file
CONDA_OVERRIDE_CUDA=12.6 pixi install

# Test
docker build -t ml-platform:test .

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

```bash
# Check CUDA is visible
docker run --rm --gpus all ghcr.io/maniaclab/ml-platform:latest nvidia-smi

# Check TensorFlow GPU support
docker run --rm --gpus all ghcr.io/maniaclab/ml-platform:latest python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

### Singularity GPU Issues

Ensure `/host-libs/` is bound to host driver paths:
```bash
singularity run --nv --bind /usr/lib/x86_64-linux-gnu:/host-libs ml-platform_main.sif
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
