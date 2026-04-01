#!/usr/bin/env bash
set -euo pipefail

# Set ENTRYPOINT_DEBUG_ENV=1 (or true) to log all environment variables on startup (secrets redacted).
entrypoint_debug_env() {
	case "${ENTRYPOINT_DEBUG_ENV:-}" in
	1 | true | yes | YES) return 0 ;;
	*) return 1 ;;
	esac
}

redact_env_dump() {
	sed -E 's/(^[^=]*(TOKEN|SECRET|PASSWORD|API_KEY|BEARER)=).*/\1<redacted>/I'
}

dump_all_env_sorted() {
	echo "=== entrypoint: full environment (sorted, sensitive values redacted) ===" >&2
	env | sort | redact_env_dump >&2
	echo "=== end environment ===" >&2
}

if entrypoint_debug_env; then
	dump_all_env_sorted
fi

# Pause between polls when the workflow or artifact is not ready yet.
WAIT_SECONDS="${INITIAL_WAIT_SECONDS:-30}"
MAX_ATTEMPTS="${INSTALL_MAX_ATTEMPTS:-120}"
# Reject artifacts whose created_at is older than this many seconds (race: avoid using a previous build).
# Set to 0 to disable (e.g. if you intentionally want to deploy an older build).
ARTIFACT_MAX_AGE_SEC="${ARTIFACT_MAX_AGE_SEC:-600}"
REPO="${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN with repo scope (actions:read for private repos)}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

mkdir -p /opt/server

server_binary() {
	# Godot "Linux Server" .zip exports typically produce an executable whose filename
	# is the zip basename (e.g. server-arm64) plus a sibling pack (e.g. server-arm64.pck).
	# So we select any top-level file except packs/archives.
	find /opt/server -maxdepth 1 -type f ! -name '*.pck' ! -name '*.zip' 2>/dev/null | head -1
}

install_from_github() {
	local run_id="$1"
	local artifact_id="$2"
	local download_url="https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip"
	echo "Downloading artifact id=${artifact_id} from run=${run_id}..."
	echo "Artifact download URL: ${download_url}"
	rm -rf /tmp/artex
	mkdir -p /tmp/artex
	if ! curl -sSL -f -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
		-o /tmp/artifact.zip \
		"${download_url}"; then
		rm -rf /tmp/artex /tmp/artifact.zip
		return 1
	fi
	if ! unzip -o -q /tmp/artifact.zip -d /tmp/artex; then
		rm -rf /tmp/artex /tmp/artifact.zip
		return 1
	fi
	local bundle
	bundle="$(find /tmp/artex -name 'server-arm64.zip' -type f | head -1)"
	if [[ -z "$bundle" ]]; then
		echo "server-arm64.zip not found inside GitHub artifact (expected Godot .zip export)."
		find /tmp/artex -type f || true
		rm -rf /tmp/artex /tmp/artifact.zip
		return 1
	fi
	find /opt/server -mindepth 1 -delete
	if ! unzip -o -q "$bundle" -d /opt/server; then
		rm -rf /tmp/artex /tmp/artifact.zip
		return 1
	fi
	rm -rf /tmp/artex /tmp/artifact.zip
	echo "Installed server bundle from workflow run ${run_id}."
	return 0
}

artifact_age_ok() {
	local created_iso="$1"
	if [[ "$ARTIFACT_MAX_AGE_SEC" == "0" ]]; then
		return 0
	fi
	local created_epoch now_epoch
	created_epoch="$(date -d "$created_iso" +%s)"
	now_epoch="$(date +%s)"
	if ((now_epoch - created_epoch > ARTIFACT_MAX_AGE_SEC)); then
		return 1
	fi
	return 0
}

attempt=0
installed=false
while [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; do
	attempt=$((attempt + 1))
	echo "Waiting ${WAIT_SECONDS}s for the next artifact check (attempt ${attempt}/${MAX_ATTEMPTS})..."
	sleep "$WAIT_SECONDS"
	echo "Starting artifact check (attempt ${attempt}/${MAX_ATTEMPTS})..."

	BRANCH_JSON="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/branches/${TARGET_BRANCH}"
	)"
	TARGET_SHA="$(
		echo "$BRANCH_JSON" | jq -r '.commit.sha // empty'
	)"
	if [[ -z "$TARGET_SHA" ]]; then
		echo "Could not resolve ${TARGET_BRANCH} HEAD SHA yet (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
		continue
	fi

	RUNS_JSON="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/workflows/godot-ci.yml/runs?branch=${TARGET_BRANCH}&status=completed&event=push&per_page=50"
	)"

	# Newest successful run that matches the current branch HEAD commit.
	RUN_ID="$(
		echo "$RUNS_JSON" | jq -r '
			[
				.workflow_runs[]
				| select(.conclusion == "success")
				| select(.head_sha == "'"${TARGET_SHA}"'")
			]
			| sort_by(.updated_at)
			| reverse
			| .[0].id // empty
		'
	)"

	if [[ -z "$RUN_ID" ]]; then
		echo "No successful godot-ci.yml run for ${TARGET_BRANCH} HEAD ${TARGET_SHA} yet (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
		continue
	fi

	ART_JSON="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/artifacts"
	)"

	ARTIFACT_ID="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .id' | head -1
	)"
	ARTIFACT_NAME="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .name' | head -1
	)"
	ARTIFACT_CREATED="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .created_at' | head -1
	)"
	ARTIFACT_SIZE="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .size_in_bytes' | head -1
	)"

	if [[ -z "$ARTIFACT_ID" ]]; then
		echo "Run ${RUN_ID} has no server-arm64 artifact yet (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
		continue
	fi
	echo "Found artifact in run ${RUN_ID}: name=${ARTIFACT_NAME} id=${ARTIFACT_ID} created_at=${ARTIFACT_CREATED} size_bytes=${ARTIFACT_SIZE}"

	if ! artifact_age_ok "$ARTIFACT_CREATED"; then
		echo "Run ${RUN_ID} artifact is older than ${ARTIFACT_MAX_AGE_SEC}s (stale vs clock); waiting for a fresher build (attempt ${attempt}/${MAX_ATTEMPTS})."
		echo "If you deploy an old commit intentionally, set ARTIFACT_MAX_AGE_SEC=0."
		continue
	fi

	if install_from_github "$RUN_ID" "$ARTIFACT_ID"; then
		installed=true
		break
	fi

	echo "Download or unpack failed (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
done

if [[ "$installed" != "true" ]]; then
	echo "Could not install server bundle after ${MAX_ATTEMPTS} attempts."
	exit 1
fi

BINARY="$(server_binary)"
if [[ -z "$BINARY" ]]; then
	echo "No server executable under /opt/server after install."
	find /opt/server -type f || true
	exit 1
fi
chmod +x "$BINARY"

echo "Server executable ready: $BINARY"
exit 0