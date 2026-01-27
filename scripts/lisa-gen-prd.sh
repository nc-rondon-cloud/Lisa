#!/bin/bash

# Source lisa-lib for LISA_MODEL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lisa-lib.sh"

claude --model "$LISA_MODEL" --permission-mode plan "want to create a site like craiglist. using ruby, sinatra, single file, code easy to understand, using jquery, less dependencies as possible, simple design like the original site. save the plan to PRD.md and exit"