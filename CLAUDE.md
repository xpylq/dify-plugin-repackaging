# CLAUDE.md

## 要求
1. 请使用中文和我交互

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository provides a shell script tool for downloading and repackaging Dify 1.0 plugins with offline dependencies. The tool fetches plugins from three sources (Dify Marketplace, GitHub releases, or local files) and bundles all Python dependencies as wheels for offline installation.

## Core Architecture

**Main Script**: `plugin_repackaging.sh` is the single entry point that:
1. Downloads .difypkg files from marketplace/GitHub or uses local files
2. Extracts the plugin package
3. Downloads all Python dependencies as platform-specific wheels using pip
4. Modifies requirements.txt to use offline wheel installation
5. Repackages using the `dify-plugin` CLI tool with increased size limits

**Platform-Specific Binaries**: Pre-compiled `dify-plugin-*` binaries for different OS/arch combinations (darwin/linux × amd64/arm64) handle the final repackaging step. The script auto-detects the current platform and selects the appropriate binary.

**Cross-Platform Repackaging**: The `-p` flag allows building packages for different target platforms than the build system (e.g., building manylinux packages on macOS).

## Environment Configuration

The script uses these configurable environment variables with defaults:
- `GITHUB_API_URL` (default: https://github.com)
- `MARKETPLACE_API_URL` (default: https://marketplace.dify.ai)
- `PIP_MIRROR_URL` (default: https://mirrors.aliyun.com/pypi/simple)

## Common Commands

### Running the Script Directly

Download and repackage from Dify Marketplace:
```bash
./plugin_repackaging.sh market [author] [name] [version]
# Example:
./plugin_repackaging.sh market langgenius agent 0.0.9
```

Download and repackage from GitHub releases:
```bash
./plugin_repackaging.sh github [repo] [release-tag] [asset-name.difypkg]
# Example:
./plugin_repackaging.sh github junjiem/dify-plugin-tools-dbquery v0.0.2 db_query.difypkg
```

Repackage local plugin:
```bash
./plugin_repackaging.sh local [path-to.difypkg]
# Example:
./plugin_repackaging.sh local ./db_query.difypkg
```

### Cross-Platform Building

Target x86_64 Linux from any platform:
```bash
./plugin_repackaging.sh -p manylinux_2_17_x86_64 market langgenius agent 0.0.9
```

Target arm64 Linux from any platform:
```bash
./plugin_repackaging.sh -p manylinux_2_17_aarch64 market langgenius agent 0.0.9
```

Custom output suffix:
```bash
./plugin_repackaging.sh -s linux-amd64 market langgenius agent 0.0.9
# Output: [name]-linux-amd64.difypkg instead of [name]-offline.difypkg
```

### Using Docker

Build the Docker image:
```bash
docker build -t dify-plugin-repackaging .
```

Run with default CMD (edit Dockerfile to change parameters):
```bash
# Linux:
docker run -v $(pwd):/app dify-plugin-repackaging

# Windows:
docker run -v %cd%:/app dify-plugin-repackaging
```

Override CMD to specify different plugin:
```bash
docker run -v $(pwd):/app dify-plugin-repackaging ./plugin_repackaging.sh -p manylinux_2_17_x86_64 market antv visualization 0.1.7
```

### GitHub Actions

Trigger the workflow manually from GitHub Actions tab with:
- plugin_author
- plugin_name
- plugin_version

The workflow uses `-p manylinux_2_17_x86_64` and uploads the resulting `-offline.difypkg` as an artifact.

## Python Version Requirement

Must use Python 3.12.x to match `dify-plugin-daemon` requirements. The pip download command explicitly targets CPython 3.12 (`--python-version 312 --implementation cp`).

## Platform-Specific Behavior

The script has different `sed` syntax for Linux vs macOS (Darwin):
- Linux: `sed -i` for in-place edits
- macOS: `sed -i ".bak"` creates backup files which are cleaned up

On Linux, the script attempts to install `unzip` via `yum` if missing. For non-RPM distros, install `unzip` manually beforehand.

## Output Files

Successful repackaging creates `[package-name]-[suffix].difypkg` where suffix defaults to "offline" or can be customized with `-s` flag. The repackaged file includes a `wheels/` directory and modified `requirements.txt` for offline installation.

## Dify Platform Configuration

To install repackaged plugins on Dify platform, update `.env`:
- `FORCE_VERIFYING_SIGNATURE=false` - Allow unsigned plugins
- `PLUGIN_MAX_PACKAGE_SIZE=524288000` - Allow 500MB plugins
- `NGINX_CLIENT_MAX_BODY_SIZE=500M` - Allow 500MB uploads
