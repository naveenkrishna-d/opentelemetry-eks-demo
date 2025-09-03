#!/usr/bin/env bash
set -euo pipefail

# Creates a sanitized tarball for sharing the demo without secrets/state.
# Output: otel-demo-clean-<date>.tgz in repo root.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

OUT="otel-demo-clean-$(date +%Y%m%d-%H%M%S).tgz"
TEMP_DIR="otel-demo-dist"
rm -rf "$TEMP_DIR" && mkdir "$TEMP_DIR"

# Copy relevant directories and files if they exist
for p in src k8s scripts terraform README.md QUICKSTART.md LICENSE grafana-dashboard-json docs; do
  if [ -e "$p" ]; then
    rsync -a --exclude 'node_modules' \
              --exclude '__pycache__' \
              --exclude '.terraform' \
              --exclude '*.pyc' \
              --exclude '*.log' \
              "$p" "$TEMP_DIR/" || true
  fi
done

# Remove Terraform state & lock (ensure clean IaC handoff)
rm -f "$TEMP_DIR/terraform/terraform.tfstate"* || true
rm -f "$TEMP_DIR/terraform/.terraform.lock.hcl" || true
rm -rf "$TEMP_DIR/terraform/.terraform" || true

# Remove any PEM keys if accidentally present
find "$TEMP_DIR" -type f -name '*.pem' -delete || true

# Insert placeholder env/example note
cat > "$TEMP_DIR/CONFIG_PLACEHOLDERS.md" <<'EOF'
# Configuration Placeholders

Provide AWS credentials via environment or `aws configure` before running scripts.
No secrets or real Terraform state are included. Recreate infrastructure with:

  ./scripts/setup-infrastructure.sh

If you need custom environment variables create a `.env` file and export before running build/deploy scripts.
EOF

# Integrity summary (checksums for all included files)
{
  echo "# FILE CHECKSUMS (SHA256)";
  find "$TEMP_DIR" -type f -print0 | sort -z | xargs -0 shasum -a 256;
} > "$TEMP_DIR/CHECKSUMS.txt"

# Create archive (maximum compression)
GZIP=-9 tar -czf "$OUT" "$TEMP_DIR"

echo "Created sanitized archive: $OUT"
echo "Inspect contents: tar -tzf $OUT | head"
echo "Done."
