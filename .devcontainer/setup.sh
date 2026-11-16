#!/usr/bin/env bash
set -euo pipefail

echo "🩺 Setting up Medsina Codespace..."

# Ensure git recognizes the workspace
git config --global --add safe.directory "$(pwd)" || true

# Initialize app_secrets.dart from example if missing so analyzer & builds work out of the box
if [ ! -f "lib/core/config/app_secrets.dart" ] && [ -f "lib/core/config/app_secrets.dart.example" ]; then
  echo "🔑 Creating lib/core/config/app_secrets.dart from example..."
  cp lib/core/config/app_secrets.dart.example lib/core/config/app_secrets.dart
fi

# Resolve Dart/Flutter workspace dependencies (root + packages/* + apps/*)
echo "📦 Running flutter pub get..."
flutter pub get

# Install Admin Dashboard dependencies
if [ -d "admin-dashboard" ] && [ -f "admin-dashboard/package.json" ]; then
  echo "⚡ Installing admin-dashboard npm dependencies..."
  npm --prefix admin-dashboard install --legacy-peer-deps
fi

echo ""
echo "✅ Medsina Codespace is ready!"
echo "Useful commands:"
echo "  • flutter analyze                                              # Run static analysis"
echo "  • flutter test                                                 # Run Flutter tests"
echo "  • flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0  # Preview Flutter Web"
echo "  • npm --prefix admin-dashboard run dev                         # Run Admin Dashboard on port 3000"
