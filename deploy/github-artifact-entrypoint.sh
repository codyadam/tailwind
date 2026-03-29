#!/usr/bin/env bash
set -euo pipefail

BINARY="/opt/server/server.arm64"
WAIT_SECONDS="${INITIAL_WAIT_SECONDS:-300}"
REPO="${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN with repo scope (actions:read for private repos)}"

if [[ ! -f "$BINARY" ]]; then
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
			| jq -r '.artifacts[] | select(.name == "linux-server-arm64") | .id' | head -1
	)"
	if [[ -z "$ARTIFACT_ID" ]]; then
		echo "Artifact linux-server-arm64 not found on run ${RUN_ID}."
		exit 1
	fi

	mkdir -p /opt/server
	rm -rf /tmp/artex
	mkdir -p /tmp/artex
	curl -sSL -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
		-o /tmp/artifact.zip \
		"https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip"
	unzip -o -q /tmp/artifact.zip -d /tmp/artex
	SERVER_PATH="$(find /tmp/artex -name 'server.arm64' -type f | head -1)"
	if [[ -z "$SERVER_PATH" ]]; then
		echo "server.arm64 not found inside artifact zip."
		find /tmp/artex -type f -maxdepth 4 || true
		exit 1
	fi
	cp -f "$SERVER_PATH" "$BINARY"
	chmod +x "$BINARY"
	rm -rf /tmp/artex /tmp/artifact.zip
	echo "Installed server binary from run ${RUN_ID}."
fi

exec "$BINARY" "$@"
