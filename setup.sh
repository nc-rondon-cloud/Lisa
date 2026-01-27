#!/bin/bash
set -e

# Get the absolute path to the lisa directory
LISA_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"

echo "🔧 Setting up Lisa..."
echo ""
echo "lisa directory: $LISA_DIR"
echo "Target file: $ZSHRC"
echo ""

# Make all scripts executable
echo "Making scripts executable..."
chmod +x "$LISA_DIR"/*.sh
chmod +x "$LISA_DIR"/scripts/*.sh 2>/dev/null || true
echo "✓ All scripts are now executable"
echo ""

# Create .zshrc if it doesn't exist
if [[ ! -f "$ZSHRC" ]]; then
    echo "Creating $ZSHRC..."
    touch "$ZSHRC"
fi

# Check if PATH entry already exists
if grep -q "export PATH=\"\$PATH:$LISA_DIR\"" "$ZSHRC"; then
    echo "✓ PATH entry already exists in $ZSHRC"
    echo "  No changes needed."
else
    echo "Adding Lisa to PATH..."
    echo "" >> "$ZSHRC"
    echo "# Lisa automation system" >> "$ZSHRC"
    echo "export PATH=\"\$PATH:$LISA_DIR\"" >> "$ZSHRC"
    echo ""
    echo "✓ Successfully added Lisa to PATH in $ZSHRC"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "To use Lisa commands from anywhere:"
echo "  1. Restart your terminal, or"
echo "  2. Run: source $ZSHRC"
echo ""
echo "Then you can run Lisa commands like:"
echo "  lisa-start.sh              # Main entry point"
echo "  scripts/lisa-once.sh       # Run one task"
echo "  scripts/lisa-afk.sh 10     # Run 10 iterations"
echo "  scripts/lisa-review.sh     # Review code"
echo ""
