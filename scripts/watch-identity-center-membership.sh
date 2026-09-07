#!/usr/bin/env bash
# Times how long a group membership change in Entra takes to reach AWS.
#
# Permission sets are assigned to groups, so a user's AWS access is exactly the
# set of IAM Identity Center groups they belong to. SCIM owns that set. Polling
# it and printing the moment it changes measures the propagation delay the
# Mover and Leaver phases claim, without reading it off a console refresh.
#
# The Identity Store API exposes no enabled or disabled flag for a user, so a
# disabled account is observed here as the loss of its group memberships, which
# is what actually removes the access.
set -euo pipefail

: "${AWS_PROFILE:=crosscloud-admin}"
: "${AWS_REGION:=eu-north-1}"
export AWS_PROFILE AWS_REGION

usage() {
    cat >&2 <<'USAGE'
Usage: watch-identity-center-membership.sh --user <userName> [options]

  --user <userName>        SCIM user name, normally the Entra userPrincipalName.
  --until <groups>         Stop when membership equals this comma-separated set.
                           Use an empty string to wait for no memberships.
  --timeout <seconds>      Give up after this long. Default 900.
  --interval <seconds>     Seconds between reads. Default 15.
  --identity-store-id <id> Skip discovery of the Identity Store.
  --once                   Print the current membership and exit.

Examples:
  # Baseline before a change.
  watch-identity-center-membership.sh --user ana@example.com --once

  # Mover: wait for the developer group to be replaced by the administrator one.
  watch-identity-center-membership.sh --user ana@example.com --until AWS-Administrators,CrossCloud-Workforce

  # Leaver: wait for every membership to disappear.
  watch-identity-center-membership.sh --user ana@example.com --until ''
USAGE
    exit 2
}

user_name=""
until_groups=""
have_until=0
timeout=900
interval=15
identity_store_id=""
once=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) user_name="${2:-}"; shift 2 ;;
        --until) until_groups="${2:-}"; have_until=1; shift 2 ;;
        --timeout) timeout="${2:-}"; shift 2 ;;
        --interval) interval="${2:-}"; shift 2 ;;
        --identity-store-id) identity_store_id="${2:-}"; shift 2 ;;
        --once) once=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

[[ -n "$user_name" ]] || usage

if [[ -z "$identity_store_id" ]]; then
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
    [[ "$identity_store_id" != "None" && -n "$identity_store_id" ]] ||
        { echo "No IAM Identity Center instance found in $AWS_REGION." >&2; exit 1; }
fi

user_id=$(aws identitystore list-users \
    --identity-store-id "$identity_store_id" \
    --filters "AttributePath=UserName,AttributeValue=$user_name" \
    --query 'Users[0].UserId' --output text)

if [[ "$user_id" == "None" || -z "$user_id" ]]; then
    echo "No IAM Identity Center user named '$user_name'. SCIM may not have provisioned it yet." >&2
    exit 1
fi

echo "Identity store : $identity_store_id"
echo "User           : $user_name ($user_id)"

# Sorted so that a set comparison does not depend on the order the API returns.
read_membership() {
    local ids
    ids=$(aws identitystore list-group-memberships-for-member \
        --identity-store-id "$identity_store_id" \
        --member-id "UserId=$user_id" \
        --query 'GroupMemberships[].GroupId' --output text)

    local names=()
    for id in $ids; do
        names+=("$(aws identitystore describe-group \
            --identity-store-id "$identity_store_id" \
            --group-id "$id" --query 'DisplayName' --output text)")
    done

    if [[ ${#names[@]} -eq 0 ]]; then
        echo ""
    else
        printf '%s\n' "${names[@]}" | sort | paste -sd, -
    fi
}

normalise() {
    # Trim spaces around each name and sort, so --until accepts either order.
    tr ',' '\n' <<<"$1" | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort | paste -sd, -
}

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

target=""
[[ $have_until -eq 1 ]] && target=$(normalise "$until_groups")

current=$(read_membership)
started_epoch=$(date -u +%s)
echo "$(stamp)  membership: ${current:-<none>}"

if [[ $once -eq 1 ]]; then
    exit 0
fi

if [[ $have_until -eq 0 ]]; then
    echo "No --until given; nothing to wait for. Re-run with --until to measure a change." >&2
    exit 0
fi

if [[ "$current" == "$target" ]]; then
    echo "Membership already matches the target. Take this reading before the change, not after."
    exit 0
fi

echo "Waiting for      : ${target:-<none>}"

while :; do
    now_epoch=$(date -u +%s)
    elapsed=$(( now_epoch - started_epoch ))
    if (( elapsed >= timeout )); then
        echo "$(stamp)  timed out after ${elapsed}s. Membership is still: ${current:-<none>}" >&2
        exit 1
    fi

    sleep "$interval"
    latest=$(read_membership)

    if [[ "$latest" != "$current" ]]; then
        current="$latest"
        elapsed=$(( $(date -u +%s) - started_epoch ))
        echo "$(stamp)  membership: ${current:-<none>}  (+${elapsed}s)"
    fi

    if [[ "$current" == "$target" ]]; then
        elapsed=$(( $(date -u +%s) - started_epoch ))
        echo "Reached the target membership ${elapsed}s after this script started."
        echo "The delay to report is measured from the workflow task completing, not from here."
        exit 0
    fi
done
