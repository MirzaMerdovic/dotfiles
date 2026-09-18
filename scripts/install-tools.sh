#!/usr/bin/env bash
#
set -Eeuo pipefail

BIN_DIR="${HOME}/.local/bin"
BITWARDEN_REPO="bitwarden/sdk-sm"

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 ||
		die "Required command not found: $1"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$BIN_DIR"

# Make newly installed tools visible during this script.
export PATH="${BIN_DIR}:${PATH}"

for command in curl jq sha256sum python3 install; do
	require_command "$command"
done

# Proton publishes no checksum and no signature for install.sh. The paths
# install.sh.sha256, install.sh.asc, and install.sh.sig all return the
# installer itself. The TLS connection to proton.me is the only integrity
# control for this download.
#
# The risk is accepted. The installer verifies the pass-cli binary against the
# SHA-256 in the manifest at https://proton.me/download/pass-cli/versions.json.
# The manifest and the binary share one origin. That check detects a corrupted
# download. It does not detect a compromise of proton.me.
install_proton_pass() {
	if command -v pass-cli >/dev/null 2>&1; then
		printf 'Proton Pass CLI already installed: '
		pass-cli --version
		return
	fi

	printf 'Installing Proton Pass CLI...\n'

	local installer="${tmp_dir}/proton-pass-install.sh"

	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--retry 3 \
		'https://proton.me/download/pass-cli/install.sh' \
		--output "$installer"

	PROTON_PASS_CLI_INSTALL_DIR="$BIN_DIR" \
		bash "$installer"

	[[ -x "${BIN_DIR}/pass-cli" ]] ||
		die "Proton Pass CLI installation failed"

	printf 'Installed: '
	pass-cli --version
}

install_bws() {
	if command -v bws >/dev/null 2>&1; then
		printf 'Bitwarden Secrets Manager CLI already installed: '
		bws --version
		return
	fi

	printf 'Installing Bitwarden Secrets Manager CLI...\n'

	local arch
	case "$(uname -m)" in
	x86_64)
		arch="x86_64"
		;;
	aarch64 | arm64)
		arch="aarch64"
		;;
	*)
		die "Unsupported architecture: $(uname -m)"
		;;
	esac

	local releases_json="${tmp_dir}/bitwarden-releases.json"

	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--retry 3 \
		"https://api.github.com/repos/${BITWARDEN_REPO}/releases?per_page=100" \
		--output "$releases_json"

	local tag
	tag="$(
		jq -r '
			map(select(.tag_name | startswith("bws-v")))
			| first
			| .tag_name // empty
		' "$releases_json"
	)"

	[[ -n "$tag" ]] ||
		die "Could not determine the latest bws release"

	local version="${tag#bws-v}"
	local asset="bws-${arch}-unknown-linux-gnu-${version}.zip"
	local checksum_asset="bws-sha256-checksums-${version}.txt"

	local base_url="https://github.com/${BITWARDEN_REPO}/releases/download/${tag}"
	local archive="${tmp_dir}/${asset}"
	local checksums="${tmp_dir}/${checksum_asset}"

	printf 'Latest bws release: %s\n' "$version"

	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--retry 3 \
		"${base_url}/${asset}" \
		--output "$archive"

	curl \
		--fail \
		--silent \
		--show-error \
		--location \
		--retry 3 \
		"${base_url}/${checksum_asset}" \
		--output "$checksums"

	local expected_checksum
	expected_checksum="$(
		awk -v file="$asset" '
			$2 == file || $2 == ("*" file) {
				print $1
				exit
			}
		' "$checksums"
	)"

	[[ -n "$expected_checksum" ]] ||
		die "Could not find checksum for ${asset}"

	local actual_checksum
	actual_checksum="$(sha256sum "$archive" | awk '{ print $1 }')"

	[[ "$actual_checksum" == "$expected_checksum" ]] ||
		die "Checksum verification failed for ${asset}"

	printf 'Checksum verified.\n'

	local extract_dir="${tmp_dir}/bws"
	mkdir -p "$extract_dir"

	python3 -m zipfile -e "$archive" "$extract_dir"

	[[ -f "${extract_dir}/bws" ]] ||
		die "bws binary not found in downloaded archive"

	install \
		--mode 0755 \
		"${extract_dir}/bws" \
		"${BIN_DIR}/bws"

	printf 'Installed: '
	bws --version
}

install_proton_pass
install_bws

printf '\nCLI tools installed successfully in %s\n' "$BIN_DIR"
