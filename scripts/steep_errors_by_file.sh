#!/bin/bash
set -euo pipefail

steep check --log-level=error | grep -o 'lib/.*rb' | sort | uniq -c | sort -nr
