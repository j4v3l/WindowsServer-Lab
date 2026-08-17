#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

host="${WSLAB_PROXMOX_HOST:-}"
node="${WSLAB_PROXMOX_NODE:-}"
ssh_user="${WSLAB_PROXMOX_SSH_USER:-root}"
identity_file="${WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH:-}"
operation="${WSLAB_REMOTE_OPERATION:-}"
site_file="${WSLAB_SITE_FILE:-}"
guest_secrets_file="${WSLAB_GUEST_SECRETS_FILE:-}"
setup_keys_file="${WSLAB_SETUP_KEYS_FILE:-}"
preflight_mode="${WSLAB_PREFLIGHT_MODE:-}"
template_os="${WSLAB_TEMPLATE_OS:-}"
allow_template_rebuild="${WSLAB_ALLOW_TEMPLATE_REBUILD:-false}"
backup_inventory_json="${WSLAB_BACKUP_INVENTORY_JSON:-}"

die() {
  printf 'Remote Terraform operation failed: %s\n' "$*" >&2
  exit 1
}

expand_home() {
  local path="$1"
  case "$path" in
    \~/*) printf '%s/%s\n' "$HOME" "${path#\~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

require_private_file() {
  local path="$1"
  local label="$2"
  local mode
  if [[ "$(uname -s)" == 'Darwin' ]]; then
    mode="$(stat -f '%Lp' "$path")"
  else
    mode="$(stat -c '%a' "$path")"
  fi
  (( (8#$mode & 077) == 0 )) || die "$label must not be readable by group or other users: $path"
}

[[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || die 'WSLAB_PROXMOX_HOST is missing or invalid'
[[ "$node" =~ ^[A-Za-z0-9._-]+$ ]] || die 'WSLAB_PROXMOX_NODE is missing or invalid'
[[ "$ssh_user" =~ ^[A-Za-z_][A-Za-z0-9._-]*$ ]] || die 'WSLAB_PROXMOX_SSH_USER is invalid'
case "$operation" in
  preflight|template-status|reconcile-template|configure-guests|backup-lab) ;;
  *) die 'WSLAB_REMOTE_OPERATION is missing or unsupported' ;;
esac

identity_file="$(expand_home "$identity_file")"
[[ -r "$identity_file" ]] || die "SSH private key is not readable: $identity_file"
[[ -r "$site_file" ]] || die "Site configuration is not readable: $site_file"

case "$operation" in
  preflight)
    case "$preflight_mode" in foundation|lab) ;; *) die 'WSLAB_PREFLIGHT_MODE must be foundation or lab' ;; esac
    ;;
  template-status|reconcile-template)
    case "$template_os" in server-2025|windows-11) ;; *) die 'WSLAB_TEMPLATE_OS must be server-2025 or windows-11' ;; esac
    ;;
  configure-guests)
    [[ -r "$guest_secrets_file" ]] || die "Guest secrets file is not readable: $guest_secrets_file"
    require_private_file "$guest_secrets_file" 'Guest secrets file'
    ;;
  backup-lab)
    jq -e 'type == "array" and all(.[]; (.id | numbers) and (.name | strings) and (.role | strings))' >/dev/null <<<"$backup_inventory_json" || die 'WSLAB_BACKUP_INVENTORY_JSON is invalid'
    ;;
esac
[[ "$allow_template_rebuild" == 'true' || "$allow_template_rebuild" == 'false' ]] || die 'WSLAB_ALLOW_TEMPLATE_REBUILD must be true or false'
if [[ -n "$setup_keys_file" ]]; then
  setup_keys_file="$(expand_home "$setup_keys_file")"
  [[ -r "$setup_keys_file" ]] || die "Setup-key file is not readable: $setup_keys_file"
  require_private_file "$setup_keys_file" 'Setup-key file'
fi

for command in base64 git jq ssh scp tar mktemp stat tr; do
  command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

local_runtime="$(mktemp -d "${TMPDIR:-/tmp}/windows-server-lab-remote.XXXXXX")"
archive_file="$local_runtime/repository.tar.gz"
file_list="$local_runtime/files.list"
nonce="$(basename "$local_runtime" | tr -cd 'A-Za-z0-9._-')"
remote_runtime="/tmp/windows-server-lab-${nonce}"
target="${ssh_user}@${host}"
remote_created='false'

ssh_options=(
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -i "$identity_file"
)

cleanup() {
  local exit_status="$?"
  if [[ "$remote_created" == 'true' && "$remote_runtime" == /tmp/windows-server-lab-* ]]; then
    ssh "${ssh_options[@]}" "$target" bash -s -- "$remote_runtime" >/dev/null 2>&1 <<'REMOTE_CLEANUP' || true
runtime="$1"
case "$runtime" in
  /tmp/windows-server-lab-*) rm -rf -- "$runtime" ;;
  *) exit 2 ;;
esac
REMOTE_CLEANUP
  fi
  if [[ -n "$local_runtime" && "$local_runtime" == "${TMPDIR:-/tmp}"/windows-server-lab-remote.* ]]; then
    rm -rf -- "$local_runtime"
  fi
  return "$exit_status"
}
trap cleanup EXIT

while IFS= read -r -d '' repository_file; do
  [[ -f "$REPO_ROOT/$repository_file" ]] || continue
  printf '%s\0' "$repository_file" >>"$file_list"
done < <(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -z)
[[ -s "$file_list" ]] || die 'No repository files were selected for remote execution'
tar_options=()
[[ "$(uname -s)" != 'Darwin' ]] || tar_options+=(--no-xattrs)
COPYFILE_DISABLE=1 tar "${tar_options[@]}" -C "$REPO_ROOT" --null -czf "$archive_file" -T "$file_list"

ssh "${ssh_options[@]}" "$target" bash -s -- "$remote_runtime" <<'REMOTE_CREATE'
set -Eeuo pipefail
umask 077
mkdir -- "$1"
REMOTE_CREATE
remote_created='true'
scp "${ssh_options[@]}" -q "$archive_file" "$target:$remote_runtime/repository.tar.gz"
scp "${ssh_options[@]}" -q "$site_file" "$target:$remote_runtime/site.json"
if [[ -n "$setup_keys_file" ]]; then
  scp "${ssh_options[@]}" -q "$setup_keys_file" "$target:$remote_runtime/setup-keys.json"
fi
if [[ "$operation" == 'configure-guests' ]]; then
  scp "${ssh_options[@]}" -q "$guest_secrets_file" "$target:$remote_runtime/guest-secrets.json"
fi
backup_inventory_base64=""
if [[ "$operation" == 'backup-lab' ]]; then
  backup_inventory_base64="$(printf '%s' "$backup_inventory_json" | base64 | tr -d '\r\n')"
fi

empty_argument='__WSLAB_EMPTY__'
preflight_argument="${preflight_mode:-$empty_argument}"
template_argument="${template_os:-$empty_argument}"
setup_keys_argument="${setup_keys_file:+present}"
setup_keys_argument="${setup_keys_argument:-$empty_argument}"
backup_argument="${backup_inventory_base64:-$empty_argument}"

if [[ "$operation" == 'configure-guests' ]]; then
  remote_job="/run/windows-server-lab-${nonce}"
  remote_unit="windows-server-lab-${nonce}"
  ssh "${ssh_options[@]}" "$target" bash -s -- \
    "$remote_runtime" "$remote_job" "$remote_unit" "$node" "$operation" "$preflight_argument" "$template_argument" "$allow_template_rebuild" "$setup_keys_argument" "$backup_argument" <<'REMOTE_START'
set -Eeuo pipefail
runtime="$1"
job="$2"
unit="$3"
shift 3
case "$runtime" in /tmp/windows-server-lab-*) ;; *) exit 2 ;; esac
case "$job" in /run/windows-server-lab-*) ;; *) exit 2 ;; esac
[[ "$unit" =~ ^windows-server-lab-[A-Za-z0-9._-]+$ ]] || exit 2
umask 077
tar -xzf "$runtime/repository.tar.gz" -C "$runtime"
chmod 0700 "$runtime"
chmod 0600 "$runtime"/*.json 2>/dev/null || true
mkdir -- "$job"
cat >"$job/run.sh" <<'RUNNER'
#!/usr/bin/env bash
set +e
runtime="$1"
job="$2"
shift 2
"$runtime/Tools/Terraform/Remote-Entrypoint.sh" "$@" >"$job/output.log" 2>&1
status="$?"
case "$runtime" in
  /tmp/windows-server-lab-*) rm -rf -- "$runtime" ;;
  *) status=2 ;;
esac
printf '%s\n' "$status" >"$job/status.tmp"
mv -- "$job/status.tmp" "$job/status"
exit "$status"
RUNNER
chmod 0700 "$job/run.sh"
if ! systemd-run --collect --unit="$unit" --property=Type=exec -- \
  /bin/bash "$job/run.sh" "$runtime" "$job" "$runtime" "$@"; then
  rm -rf -- "$job"
  exit 1
fi
REMOTE_START
  # The transient service now owns removal of the runtime and its secret file.
  remote_created='false'
  poll_deadline="$(( $(date +%s) + 28800 ))"
  while true; do
    poll_result=""
    if poll_result="$(ssh "${ssh_options[@]}" "$target" bash -s -- "$remote_job" "$remote_unit" <<'REMOTE_POLL'
set -Eeuo pipefail
job="$1"
unit="$2"
case "$job" in /run/windows-server-lab-*) ;; *) exit 2 ;; esac
if [[ -r "$job/status" ]]; then
  printf 'done:%s\n' "$(cat "$job/status")"
elif systemctl is-active --quiet "$unit"; then
  printf 'running\n'
elif systemctl show "$unit" -p LoadState --value 2>/dev/null | grep -Fxq loaded; then
  printf 'starting\n'
else
  printf 'missing\n'
fi
REMOTE_POLL
)"; then
      case "$poll_result" in
        running|starting) ;;
        missing) die 'Remote guest job disappeared before producing a status result' ;;
        done:*)
          set +e
          ssh "${ssh_options[@]}" "$target" bash -s -- "$remote_job" <<'REMOTE_RESULT'
set -Eeuo pipefail
job="$1"
case "$job" in /run/windows-server-lab-*) ;; *) exit 2 ;; esac
status="$(cat "$job/status")"
[[ "$status" =~ ^[0-9]+$ ]] || exit 2
cat "$job/output.log" 2>/dev/null || true
rm -rf -- "$job"
exit "$status"
REMOTE_RESULT
          result_status="$?"
          set -e
          exit "$result_status"
          ;;
        *) die "Unexpected remote job state: $poll_result" ;;
      esac
    fi
    (( $(date +%s) < poll_deadline )) || die 'Remote guest configuration did not finish within eight hours'
    sleep 10
  done
fi

ssh "${ssh_options[@]}" "$target" bash -s -- \
  "$remote_runtime" "$node" "$operation" "$preflight_argument" "$template_argument" "$allow_template_rebuild" "$setup_keys_argument" "$backup_argument" <<'REMOTE'
set -Eeuo pipefail
runtime="$1"
cleanup_remote() {
  case "$runtime" in
    /tmp/windows-server-lab-*) rm -rf -- "$runtime" ;;
    *) return 2 ;;
  esac
}
trap cleanup_remote EXIT HUP INT TERM
tar -xzf "$runtime/repository.tar.gz" -C "$runtime"
chmod 0700 "$runtime"
chmod 0600 "$runtime"/*.json 2>/dev/null || true
"$runtime/Tools/Terraform/Remote-Entrypoint.sh" "$@"
REMOTE
