# Instructions for AI Coding Agents

This file contains specific instructions for AI coding agents (like Claude) working on this repository.

## Repository Context

This is a Docker image repository for the MaNIAC Lab ML platform. All dependencies are managed via Pixi (conda-forge + PyPI) and the image is built via GitHub Actions.

## Critical Rules

### 1. Pixi Dependency Management

**ALWAYS commit both `pixi.toml` AND `pixi.lock` together.**

When modifying dependencies:
```bash
vim pixi.toml  # Make changes
CONDA_OVERRIDE_CUDA=12.6 pixi install  # Regenerate lock file
git add pixi.toml pixi.lock  # Commit both
```

**NEVER:**
- Commit `pixi.toml` without regenerating `pixi.lock`
- Delete or gitignore `pixi.lock` (it ensures reproducibility)
- Modify `pixi.lock` manually

### 2. Pixi Environments and Two Separate Images

The repository builds **two separate images** from the same `Dockerfile` and `pixi.toml`, parameterized
by build args:

- **`ml-platform-gpu`**: `BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0`,
  `PIXI_ENVIRONMENT=ml` (feature `mlbase` + `mlgpu`; declares `cuda = "13.0"` as a
  `system-requirements`, depends on `tensorflow-gpu`).
- **`ml-platform-cpu`**: `BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble` (no CUDA in the base image at all),
  `PIXI_ENVIRONMENT=mlcpu` (feature `mlbase` + `mlcpu`; no `cuda` system-requirement, depends on plain
  `tensorflow`).
- **dev environment** (development, not shipped in either image): Python 3.11, tbump for versioning.
  Used locally for version management.

Each image only ever installs and ships the *one* environment it was built for — there is no runtime
GPU probing or environment dispatcher. This is deliberate: shipping the GPU environment's dependencies
in a plain (non-CUDA) base image would still work for imports, but shipping the *CUDA base image* for a
CPU-only deployment is what caused the original bug (see git history) — that base image bakes
`NVIDIA_REQUIRE_CUDA` into `ENV`, so container runtimes with `default-runtime: nvidia` enforce a driver
version check even when no GPU is requested. Using the plain `noble` base for the CPU image avoids that
class of failure structurally, not just via `pixi`-level workarounds.

When modifying dependencies:
- Add shared production packages to `[feature.mlbase.dependencies]` or `[feature.mlbase.pypi-dependencies]`
- Add GPU-only packages to `[feature.mlgpu.dependencies]`, CPU-only packages to `[feature.mlcpu.dependencies]`
- Add development tools to `[feature.dev.dependencies]`

Test both images locally, since they build independently and can diverge:
```bash
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
  --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
  --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .
```

### 3. Dockerfile Commands

**ALWAYS prefix commands with `/app/entrypoint.sh` in the final stage.**

The entrypoint activates the Pixi environment (a plain `pixi shell-hook` script, no dispatching logic).
Without it, tools like `curl`, `git`, `python` won't be in PATH.

```dockerfile
# ✅ CORRECT
RUN /app/entrypoint.sh curl -O https://example.com/file
RUN /app/entrypoint.sh git clone https://github.com/user/repo
RUN /app/entrypoint.sh python -m pip install package

# ❌ WRONG - will fail with "command not found"
RUN curl -O https://example.com/file
RUN git clone https://github.com/user/repo
RUN python -m pip install package
```

### 4. Modifying the Image

When changing dependencies or Dockerfile:

1. **Test locally BEFORE committing (both images):**
   ```bash
   docker build --platform linux/amd64 \
     --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
     --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
   docker build --platform linux/amd64 \
     --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
     --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .
   docker run --rm ml-platform-cpu:test <command-to-verify>
   ```

2. **Commit related files together:**
   - If changing dependencies: commit `pixi.toml` + `pixi.lock`
   - If changing Dockerfile: test that build succeeds
   - If changing config files: include them in same commit

3. **Use semantic commit messages:**
   - `feat:` for new capabilities
   - `fix:` for bug fixes
   - `chore:` for dependency updates
   - `refactor:` for restructuring without behavior change

### 5. Version Management

This project uses **CalVer (Calendar Versioning)** with format `YYYY.M.D`.

**Creating a release (recommended):**
```bash
pixi run -e dev bump  # Uses current date
```

**Manual release:**
```bash
pixi run -e dev tbump 2026.2.19
```

This automatically:
1. Updates `pixi.toml` and `tbump.toml`
2. Creates a commit: `Release YYYY.M.D`
3. Creates a git tag: `vYYYY.M.D`
4. Pushes the tag to trigger CI/CD

See `CONTRIBUTING.md` for detailed versioning documentation.

### 6. Workflow Behavior

The `.github/workflows/build-images.yaml` builds the image on every trigger.

**Key points:**
- A 2-entry `strategy.matrix` (`gpu`, `cpu`) builds both images from the same `Dockerfile`, varying
  `BASE_IMAGE` and `PIXI_ENVIRONMENT` build-args per matrix entry
- Context is `.` (repo root), dockerfile is `./Dockerfile` for both matrix entries
- Uses CalVer tags for releases
- `fail-fast: false` so a failure building one variant doesn't cancel the other

**Build triggers:**
- **Push to main:** Build both images, push each with tags `latest`, `sha-abc1234`
- **Git tag `v*`:** Build both images, push each with tags `YYYY.M.D`, `YYYY.MM`, `sha-abc1234`
- **Pull request:** Build both images (validation only, no push)
- **Manual dispatch:** Build both images, push to registries

**Tag behavior** (per image — `ml-platform-gpu` and `ml-platform-cpu` are tagged identically):

| Trigger | Tags |
|---------|------|
| Push to `main` | `latest`, `sha-abc1234` |
| Git tag `v2026.2.11` | `2026.2.11`, `2026.2`, `sha-abc1234` |
| Pull request | `sha-abc1234` (no push) |

**When modifying workflow:**
- ALWAYS validate YAML syntax (use yamllint or IDE validation)
- NEVER hardcode secrets in workflow (use `${{ secrets.NAME }}`)

### 7. Common Mistakes to Avoid

❌ **Using `[project]` instead of `[workspace]` in pixi.toml**
- Modern pixi uses `[workspace]`, not `[project]`

❌ **Not prefixing commands with entrypoint**
- Leads to "command not found" errors in Docker build

❌ **Committing pixi.toml without pixi.lock**
- Breaks reproducibility

❌ **Not testing Docker build locally**
- CI failures waste time; test locally first

❌ **Adding dependencies to wrong feature**
- Use `[feature.mlbase.dependencies]` for packages needed by both `ml` and `mlcpu`
- Use `[feature.mlgpu.dependencies]` / `[feature.mlcpu.dependencies]` for environment-specific packages
- Use `[feature.dev.dependencies]` for development tools
- Use `[feature.mlbase.pypi-dependencies]` for PyPI-only shared production packages

❌ **Testing only one image variant**
- The `ml-platform-gpu` and `ml-platform-cpu` images build independently from different `BASE_IMAGE`
  build-args; a change that works for one can break the other (different pixi version in the base
  image, different available system packages, etc.) — build and test both.

### 8. Testing Requirements

Before committing changes that affect Docker builds:

1. **Both images build:**
   ```bash
   docker build --platform linux/amd64 \
     --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
     --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .
   docker build --platform linux/amd64 \
     --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
     --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .
   ```

2. **Environment activates:**
   ```bash
   docker run --rm ml-platform-cpu:test python --version
   ```

3. **Key packages import:**
   ```bash
   docker run --rm ml-platform-cpu:test python -c "import tensorflow, keras, numpy, pandas; print('OK')"
   docker run --rm ml-platform-cpu:test root --version
   docker run --rm ml-platform-cpu:test jupyter --version
   ```
   Repeat with `ml-platform-gpu:test` (the GPU image will only actually exercise the GPU path on a
   host with a compatible NVIDIA driver and `--gpus all`).

### 9. Repository State Awareness

**Key files to check before making changes:**
- `.github/workflows/build-images.yaml` - workflow configuration (matrix: gpu/cpu)
- `pixi.toml` - dependency definitions: `mlbase`/`mlgpu`/`mlcpu`/`dev` features, `ml`/`mlcpu`/`dev` environments
- `pixi.lock` - locked versions (DO NOT MODIFY MANUALLY)
- `Dockerfile` - single parameterized build (`BASE_IMAGE`, `PIXI_ENVIRONMENT` build-args), used for both images
- `config/jupyter_notebook_config.py` - Jupyter configuration
- `config/SetupPrivateJupyterLab.sh` - JupyterLab setup script
- `tbump.toml` - version bumping configuration
- `CONTRIBUTING.md` - developer documentation

### 10. Build Behavior

The workflow builds **both** `ml-platform-gpu` and `ml-platform-cpu` on every trigger, via a matrix,
for simplicity and consistency.

**Build triggers:**
- **Push to main:** Build and push both images with `latest` and SHA tags
- **Git tag `v*`:** Build and push both images with CalVer tags (YYYY.M.D, YYYY.MM) and SHA tags
- **Pull request:** Build both images for validation (no push)
- **Manual dispatch:** Build and push both images

**No change detection:** The workflow intentionally does not use path filters. This simplifies maintenance and ensures builds stay consistent.

### 11. Git Workflow

**Commit frequently** with logical groupings:
- Dependency changes: pixi.toml + pixi.lock together
- Dockerfile changes: standalone if not tied to dependency updates
- Config file changes: include in relevant commit
- Version bumps: use `pixi run -e dev bump` (automated)

**Semantic commit format:**
```
<type>: <short description>

<detailed explanation>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Types:** feat, fix, chore, refactor, docs, test, ci

## When to Ask for Clarification

**ALWAYS ask the user before:**
- Changing base image version (affects entire build)
- Modifying registry configurations
- Adding new registry authentication requirements
- Changing CUDA version
- Making breaking changes to the image
- Creating a version release (unless explicitly instructed)

**You can proceed without asking when:**
- Adding new dependencies to pixi.toml (assuming you regenerate lock)
- Fixing obvious bugs in Dockerfile
- Improving documentation
- Updating non-breaking dependency versions

## Useful Commands Reference

```bash
# Generate/update pixi lock file
CONDA_OVERRIDE_CUDA=12.6 pixi install

# Test local build (GPU image)
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble-cuda-13.0.0 \
  --build-arg PIXI_ENVIRONMENT=ml -t ml-platform-gpu:test .

# Test local build (CPU image)
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=ghcr.io/prefix-dev/pixi:noble \
  --build-arg PIXI_ENVIRONMENT=mlcpu -t ml-platform-cpu:test .

# Run verification tests
docker run --rm ml-platform-cpu:test <command>

# Interactive shell for debugging
docker run --rm -it ml-platform-cpu:test bash

# Check pixi environment
docker run --rm ml-platform-cpu:test pixi list

# View current git status
git status

# Check workflow syntax
yamllint .github/workflows/build-images.yaml

# Version management (dev environment)
pixi run -e dev bump  # Quick release with current date
pixi run -e dev tbump 2026.2.19  # Manual date selection
pixi run -e dev tbump current-version  # Check current version
```

## Success Criteria

A change is complete when:
1. ✅ Docker build succeeds locally
2. ✅ Verification tests pass
3. ✅ Both pixi.toml and pixi.lock committed (if dependencies changed)
4. ✅ Commit message is semantic and descriptive
5. ✅ README.md updated if user-facing behavior changed
6. ✅ CONTRIBUTING.md updated if developer workflow changed

## Additional Context

This repository consolidates what were previously two separate repositories (ml_base and ml_platform) into a single repository with modern tooling:
- **Before:** apt-get + pip venv, separate repos, manual builds
- **After:** Pixi + conda-forge, single image repo, automated CI/CD, CalVer versioning

The goal is maintainability, reproducibility, and simplicity.

## For More Information

- **CONTRIBUTING.md** - Comprehensive developer guide with setup, testing, and release procedures
- **README.md** - User-facing documentation about the image and its features
- **tbump.toml** - Version bumping configuration for CalVer releases
