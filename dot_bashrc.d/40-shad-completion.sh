# shellcheck shell=bash
# shad bash completion.
#
# Sourced from the installed binary on every shell start, so it can never
# drift from the CLI. Do not paste the script text in here.
if command -v shad >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source <(shad completion bash)
fi
