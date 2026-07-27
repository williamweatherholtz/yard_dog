#!/bin/sh
# Yard Dog installer — downloads the right release binary for your OS/arch,
# verifies its SHA256 against the published SHA256SUMS, and installs it.
#   curl -fsSL https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/install.sh | sh
set -eu

REPO="williamweatherholtz/yard_dog"

os=$(uname -s)
arch=$(uname -m)
case "$os" in
  Linux)  o=linux ;;
  Darwin) o=macos ;;
  *) echo "yd: unsupported OS '$os' — install a release binary manually from https://github.com/$REPO/releases" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64|amd64)   a=x86_64 ;;
  aarch64|arm64)  a=aarch64 ;;
  *) echo "yd: unsupported arch '$arch'" >&2; exit 1 ;;
esac
asset="yd-${a}-${o}"

echo "yd: resolving latest release…"
tag=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
[ -n "$tag" ] || { echo "yd: could not resolve latest release" >&2; exit 1; }
base="https://github.com/$REPO/releases/download/$tag"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "yd: downloading $asset ($tag)…"
curl -fsSL -o "$tmp/yd" "$base/$asset" \
  || { echo "yd: no prebuilt binary '$asset' for this platform in $tag" >&2; exit 1; }
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"

want=$(awk -v a="$asset" '$2==a {print $1}' "$tmp/SHA256SUMS")
if command -v sha256sum >/dev/null 2>&1; then
  got=$(sha256sum "$tmp/yd" | awk '{print $1}')
else
  got=$(shasum -a 256 "$tmp/yd" | awk '{print $1}')
fi
[ -n "$want" ] || { echo "yd: no checksum for $asset in SHA256SUMS" >&2; exit 1; }
[ "$want" = "$got" ] || { echo "yd: SHA256 mismatch — refusing to install (want $want got $got)" >&2; exit 1; }
echo "yd: checksum OK"

chmod +x "$tmp/yd"
if [ -w /usr/local/bin ] || [ "$(id -u)" = "0" ]; then dest=/usr/local/bin; else dest="$HOME/.local/bin"; fi
mkdir -p "$dest"
mv "$tmp/yd" "$dest/yd"
echo "yd: installed $tag to $dest/yd"
case ":$PATH:" in *":$dest:"*) : ;; *) echo "yd: add $dest to your PATH to run 'yd'";; esac
