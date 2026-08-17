#!/usr/bin/env bash
set -euo pipefail

emerge --sync
/usr/local/bin/refresh-portage-cache.sh
