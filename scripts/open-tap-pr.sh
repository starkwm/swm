#!/usr/bin/env bash
set -eo pipefail

formula=Formula/swm.rb
candidate=../release/swm.rb
branch="swm-$TAG"
if cmp -s "$formula" "$candidate"; then
  echo "The tap already has the tested formula for $TAG."
  exit 0
fi
if [[ "$(git hash-object "$formula")" != "$(cat ../release/tap-formula-base)" ]]; then
  echo 'The tap formula changed after the bottle was built.' >&2
  exit 1
fi

# Reuse a branch from an earlier attempt only if it contains this formula.
existing=$(git ls-remote origin "refs/heads/$branch")
if [[ -n "$existing" ]]; then
  git fetch origin "refs/heads/$branch"
  git show "FETCH_HEAD:$formula" | cmp - "$candidate"
else
  cp "$candidate" "$formula"
  git add "$formula"
  git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m "Update swm to $TAG"
  git push origin "HEAD:refs/heads/$branch"
fi

pulls="repos/$TAP_REPOSITORY/pulls"
pr=$(gh api --method GET "$pulls" -f state=open -f base=main \
  -f head="${TAP_REPOSITORY%/*}:$branch" --jq '.[0].html_url // empty')
if [[ -z "$pr" ]]; then
  gh api --method POST "$pulls" -f base=main -f head="$branch" -f title="Update swm to $TAG" \
    -f body="Source and Golden Gate bottle for $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$TAG." \
    -F maintainer_can_modify=false --jq .html_url
else
  echo "$pr"
fi
