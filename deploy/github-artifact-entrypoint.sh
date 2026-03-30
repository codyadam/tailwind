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

print_commit_env_hints() {
	echo "--- Commit / deploy related (safe preview) ---" >&2
	local n
	for n in SERVER_COMMIT_SHA GITHUB_SHA SOURCE_COMMIT COOLIFY_BRANCH COOLIFY_FQDN; do
		local val="${!n:-}"
		if [[ -n "$val" ]]; then
			echo "${n}=<set, length ${#val}>" >&2
		else
			echo "${n}=<unset>" >&2
		fi
	done
	echo "--- Other env names matching COOLIFY|GITHUB|SOURCE|GIT|COMMIT (values redacted) ---" >&2
	# shellcheck disable=SC2046
	env | sort | grep -iE '^(COOLIFY|GITHUB|SOURCE|GIT|COMMIT)' | redact_env_dump >&2 || true
	echo "--- end hints ---" >&2
}

if entrypoint_debug_env; then
	dump_all_env_sorted
fi

# Pause between polls when the right workflow or artifact is not ready yet.
WAIT_SECONDS="${INITIAL_WAIT_SECONDS:-30}"
MAX_ATTEMPTS="${INSTALL_MAX_ATTEMPTS:-120}"
# Reject artifacts whose created_at is older than this many seconds (race: avoid using a previous build).
# Set to 0 to disable (e.g. deploying an older commit).
ARTIFACT_MAX_AGE_SEC="${ARTIFACT_MAX_AGE_SEC:-600}"

REPO="${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN with repo scope (actions:read for private repos)}"

# Commit this deploy expects (same as the push that should have triggered godot-ci). Prevents downloading
# the previous successful run while the new workflow is still running.
# Coolify sets SOURCE_COMMIT for git-based deploys; enable it at runtime if it is build-only in your app settings.
WANT_SHA_RAW="${SERVER_COMMIT_SHA:-${GITHUB_SHA:-${SOURCE_COMMIT:-}}}"
if [[ -z "$WANT_SHA_RAW" ]]; then
	echo "No commit SHA in environment. Set one of: SERVER_COMMIT_SHA, GITHUB_SHA, or SOURCE_COMMIT (Coolify)."
	echo "Coolify: use runtime SOURCE_COMMIT=\$SOURCE_COMMIT in the UI. Ensure compose does not set SOURCE_COMMIT: \${SOURCE_COMMIT:-} (that forces empty and overrides Coolify)."
	echo "Local: add GITHUB_SHA to .env (see docker-compose env_file) or export before compose up."
	echo "Tip: set ENTRYPOINT_DEBUG_ENV=1 on a successful path to dump env at every container start (tokens redacted)."
	print_commit_env_hints
	echo "=== Full environment (sorted, sensitive values redacted) — missing commit SHA ===" >&2
	env | sort | redact_env_dump >&2
	echo "=== end ===" >&2
	exit 1
fi
WANT_SHA="$(echo "$WANT_SHA_RAW" | tr '[:upper:]' '[:lower:]')"

mkdir -p /opt/server

server_binary() {
	find /opt/server -maxdepth 1 -type f -name '*.arm64' 2>/dev/null | head -1
}

install_from_github() {
	local run_id="$1"
	local artifact_id="$2"
	rm -rf /tmp/artex
	mkdir -p /tmp/artex
	if ! curl -sSL -f -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
		-o /tmp/artifact.zip \
		"https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip"; then
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

	RUNS_JSON="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/workflows/godot-ci.yml/runs?branch=main&status=success&per_page=50"
	)"

	# Newest successful run for this commit (by updated_at) so re-runs beat an older green run for the same SHA.
	RUN_ID="$(
		echo "$RUNS_JSON" | jq -r --arg want "$WANT_SHA" '
			[.workflow_runs[]
				| select(
					(.head_sha | ascii_downcase) as $h
					| ($h == $want) or ($h | startswith($want))
				)
			]
			| sort_by(.updated_at) | reverse
			| .[0].id // empty
		'
	)"

	if [[ -z "$RUN_ID" ]]; then
		echo "No successful godot-ci.yml run on main for commit ${WANT_SHA_RAW} (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
		sleep "$WAIT_SECONDS"
		continue
	fi

	ART_JSON="$(
		curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/artifacts"
	)"

	ARTIFACT_ID="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .id' | head -1
	)"
	ARTIFACT_CREATED="$(
		echo "$ART_JSON" | jq -r '.artifacts[] | select(.name == "server-arm64") | .created_at' | head -1
	)"

	if [[ -z "$ARTIFACT_ID" ]]; then
		echo "Run ${RUN_ID} matches ${WANT_SHA_RAW} but server-arm64 artifact not ready (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
		sleep "$WAIT_SECONDS"
		continue
	fi

	if ! artifact_age_ok "$ARTIFACT_CREATED"; then
		echo "Run ${RUN_ID} artifact is older than ${ARTIFACT_MAX_AGE_SEC}s (stale vs clock); waiting for a fresher build (attempt ${attempt}/${MAX_ATTEMPTS})."
		echo "If you deploy an old commit intentionally, set ARTIFACT_MAX_AGE_SEC=0."
		sleep "$WAIT_SECONDS"
		continue
	fi

	if install_from_github "$RUN_ID" "$ARTIFACT_ID"; then
		installed=true
		break
	fi

	echo "Download or unpack failed (attempt ${attempt}/${MAX_ATTEMPTS}); sleeping ${WAIT_SECONDS}s..."
	sleep "$WAIT_SECONDS"
done

if [[ "$installed" != "true" ]]; then
	echo "Could not install server bundle after ${MAX_ATTEMPTS} attempts."
	exit 1
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
	exit 1
fi
exec "$BINARY" --main-pack "$PCK_FALLBACK" "$@"
