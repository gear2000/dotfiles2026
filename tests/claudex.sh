#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " != *" --header Authorization: Bearer claudex-loopback "* ]]; then
  echo "fake curl: missing loopback authorization header" >&2
  exit 22
fi
if [[ "${FAKE_CURL_FAIL:-0}" == 1 ]]; then
  echo "fake curl: connection refused" >&2
  exit 7
fi
if [[ -n "${FAKE_MODELS_JSON:-}" ]]; then
  printf '%s\n' "$FAKE_MODELS_JSON"
else
  printf '%s\n' '{"data":[{"id":"gpt-5.6-sol"},{"id":"custom-model"}]}'
fi
SH

cat >"$tmp_dir/bin/claude" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL-}"
  printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "${ANTHROPIC_AUTH_TOKEN-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL-}"
  printf 'CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=%s\n' "${CLAUDE_CODE_ALWAYS_ENABLE_EFFORT-}"
  printf 'CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=%s\n' "${CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY-}"
  printf 'ENABLE_TOOL_SEARCH=%s\n' "${ENABLE_TOOL_SEARCH-}"
  printf 'ARG=%s\n' "$@"
} >"$CLAUDEX_TEST_CAPTURE"
SH

cat >"$tmp_dir/bin/cli-proxy-api" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'ARG=%s\n' "$@" >"$CLAUDEX_TEST_CAPTURE"
SH
chmod +x "$tmp_dir/bin/"*

export PATH="$tmp_dir/bin:$PATH"
export CLAUDEX_TEST_CAPTURE="$tmp_dir/capture"

bash "$repo_dir/modules/scripts/claudex" --dangerously-skip-permissions -p 'native prompt'
grep -Fx 'ANTHROPIC_BASE_URL=http://127.0.0.1:8317' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'ANTHROPIC_AUTH_TOKEN=claudex-loopback' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'ENABLE_TOOL_SEARCH=false' "$CLAUDEX_TEST_CAPTURE"
expected_default=$'ARG=--model\nARG=gpt-5.6-sol\nARG=--effort\nARG=high\nARG=--dangerously-skip-permissions\nARG=-p\nARG=native prompt'
[[ "$(grep '^ARG=' "$CLAUDEX_TEST_CAPTURE")" == "$expected_default" ]]

bash "$repo_dir/modules/scripts/claudex" custom-model --effort max -- 'positional prompt'
grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=custom-model' "$CLAUDEX_TEST_CAPTURE"
expected_custom=$'ARG=--model\nARG=custom-model\nARG=--effort\nARG=max\nARG=--\nARG=positional prompt'
[[ "$(grep '^ARG=' "$CLAUDEX_TEST_CAPTURE")" == "$expected_custom" ]]

bash "$repo_dir/modules/scripts/claudex" --model custom-model --print 'native model flag'
grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=custom-model' "$CLAUDEX_TEST_CAPTURE"
expected_native_model=$'ARG=--effort\nARG=high\nARG=--model\nARG=custom-model\nARG=--print\nARG=native model flag'
[[ "$(grep '^ARG=' "$CLAUDEX_TEST_CAPTURE")" == "$expected_native_model" ]]

if bash "$repo_dir/modules/scripts/claudex" --model --print >/dev/null 2>"$tmp_dir/model-error"; then
	echo "expected claudex to reject a missing --model value" >&2
	exit 1
fi
grep -F -- '--model requires a value' "$tmp_dir/model-error"

# claudex's exports are child-local; invoking raw claude does not inherit them.
"$tmp_dir/bin/claude" --version
grep -Fx 'ANTHROPIC_BASE_URL=' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'ANTHROPIC_AUTH_TOKEN=' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_SUBAGENT_MODEL=' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=' "$CLAUDEX_TEST_CAPTURE"
grep -Fx 'ENABLE_TOOL_SEARCH=' "$CLAUDEX_TEST_CAPTURE"
[[ "$(grep '^ARG=' "$CLAUDEX_TEST_CAPTURE")" == 'ARG=--version' ]]

rm -f "$CLAUDEX_TEST_CAPTURE"
if FAKE_MODELS_JSON='{"data":[{"id":"other-model"}]}' \
	bash "$repo_dir/modules/scripts/claudex" >/dev/null 2>"$tmp_dir/error"; then
	echo "expected claudex to reject an unavailable model" >&2
	exit 1
fi
grep -F "model 'gpt-5.6-sol' is not available" "$tmp_dir/error"
[[ ! -e "$CLAUDEX_TEST_CAPTURE" ]]

doctor_home="$tmp_dir/doctor-home"
mkdir -p "$doctor_home/.cli-proxy-api"
printf '{}\n' >"$doctor_home/.cli-proxy-api/codex-test.json"
HOME="$doctor_home" bash "$repo_dir/modules/scripts/claudex-doctor" | grep -Fx \
	'claudex-doctor: ok; CLIProxyAPI advertises gpt-5.6-sol'

mkdir -p "$tmp_dir/no-auth-home"
if HOME="$tmp_dir/no-auth-home" \
	bash "$repo_dir/modules/scripts/claudex-doctor" >/dev/null 2>"$tmp_dir/doctor-error"; then
	echo "expected claudex-doctor to reject missing OAuth state" >&2
	exit 1
fi
grep -F 'no Codex OAuth session; run claudex-login' "$tmp_dir/doctor-error"

if HOME="$tmp_dir/no-auth-home" FAKE_CURL_FAIL=1 \
	bash "$repo_dir/modules/scripts/claudex-doctor" >/dev/null 2>"$tmp_dir/service-error"; then
	echo "expected claudex-doctor to reject a stopped proxy" >&2
	exit 1
fi
grep -F 'CLIProxyAPI is unavailable at http://127.0.0.1:8317' "$tmp_dir/service-error"

HOME="$tmp_dir/home" XDG_CONFIG_HOME="$tmp_dir/xdg" \
	bash "$repo_dir/modules/scripts/claudex-login"
expected_device_login=$'ARG=--config\nARG='"$tmp_dir"$'/xdg/cli-proxy-api/config.yaml\nARG=--codex-device-login\nARG=--no-browser'
[[ "$(cat "$CLAUDEX_TEST_CAPTURE")" == "$expected_device_login" ]]

HOME="$tmp_dir/home" XDG_CONFIG_HOME="$tmp_dir/xdg" \
	bash "$repo_dir/modules/scripts/claudex-login" --browser --no-browser
expected_browser_login=$'ARG=--config\nARG='"$tmp_dir"$'/xdg/cli-proxy-api/config.yaml\nARG=--codex-login\nARG=--no-browser'
[[ "$(cat "$CLAUDEX_TEST_CAPTURE")" == "$expected_browser_login" ]]

bash "$repo_dir/modules/scripts/claudex-login" --help | grep -F \
	'usage: claudex-login [--device|--browser]'

# Locked public safety settings and both user-service implementations remain
# visible to this focused check even when only one OS can build locally.
# shellcheck disable=SC2016
grep -F 'host: "${proxyHost}"' "$repo_dir/modules/claudex.nix"
grep -F 'proxyHost = "127.0.0.1"' "$repo_dir/modules/claudex.nix"
grep -F 'allow-remote: false' "$repo_dir/modules/claudex.nix"
grep -F 'secret-key: ""' "$repo_dir/modules/claudex.nix"
grep -F 'disable-control-panel: true' "$repo_dir/modules/claudex.nix"
grep -F '      - "claudex-loopback"' "$repo_dir/modules/claudex.nix"
grep -F 'systemd.user.services.cli-proxy-api' "$repo_dir/modules/claudex.nix"
grep -F 'launchd.agents.cli-proxy-api' "$repo_dir/modules/claudex.nix"
grep -F 'llm-agents.overlays.shared-nixpkgs' "$repo_dir/flake.nix"

printf 'ClaudeX wrapper and safety checks passed.\n'
