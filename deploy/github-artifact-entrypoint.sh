#!/usr/bin/env bash
set -euo pipefail

WAIT_SECONDS="${INITIAL_WAIT_SECONDS:-300}"
REPO="${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN with repo scope (actions:read for private repos)}"

mkdir -p /opt/server

server_binary() {
	find /opt/server -maxdepth 1 -type f -name '*.arm64' 2>/dev/null | head -1
}

if [[ -z "$(server_binary)" ]]; then
	echo "No server binary in volume; waiting ${WAIT_SECONDS}s for CI to finish..."
	sleep "$WAIT_SECONDS"

	RUN_ID="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/workflows/godot-ci.yml/runs?branch=main&status=success&per_page=1" \
			| jq -r '.workflow_runs[0].id // empty'
	)"
	if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
		echo "No successful workflow run found on main for godot-ci.yml."
		exit 1
	fi

	ARTIFACT_ID="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/artifacts" \
			| jq -r '.artifacts[] | select(.name == "server-arm64") | .id' | head -1
	)"
	if [[ -z "$ARTIFACT_ID" ]]; then
		echo "Artifact server-arm64 not found on run ${RUN_ID}."
		exit 1
	fi

	rm -rf /tmp/artex
	mkdir -p /tmp/artex
	curl -sSL -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
		-o /tmp/artifact.zip \
		"https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip"
	unzip -o -q /tmp/artifact.zip -d /tmp/artex
	BUNDLE="$(find /tmp/artex -name 'server-arm64.zip' -type f | head -1)"
	if [[ -z "$BUNDLE" ]]; then
		echo "server-arm64.zip not found inside GitHub artifact (expected Godot .zip export)."
		find /tmp/artex -type f || true
		exit 1
	fi
	unzip -o -q "$BUNDLE" -d /opt/server
	rm -rf /tmp/artex /tmp/artifact.zip
	echo "Installed server bundle from run ${RUN_ID}."
fi

BINARY="$(server_binary)"
if [[ -z "$BINARY" ]]; then
	echo "No *.arm64 binary under /opt/server after install."
	find /opt/server -type f || true
	exit 1
fi
chmod +x "$BINARY"

PCK="${BINARY}.pck"
if [[ -f "$PCK" ]]; then
	exec "$BINARY" "$@"
fi

PCK_FALLBACK="$(find /opt/server -maxdepth 1 -type f -name '*.pck' | head -1)"
if [[ -z "$PCK_FALLBACK" ]]; then
	echo "No .pck next to ${BINARY} and no *.pck in /opt/server."
	echo "Remove the server volume and redeploy:"
	echo "  docker compose down && docker volume rm tailwind_server_data && docker compose up -d"
	exit 1
fi
exec "$BINARY" --main-pack "$PCK_FALLBACK" "$@"
