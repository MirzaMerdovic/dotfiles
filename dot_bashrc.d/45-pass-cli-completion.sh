# shellcheck shell=bash
# Proton Pass CLI bash completion.
#
# Sourced from the installed binary on every shell start, so it can never
# drift from the CLI. Do not paste the script text in here.
#
# The subcommand is 'completions', not 'completion'.
if command -v pass-cli >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source <(pass-cli completions bash)
fi
