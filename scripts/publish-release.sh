#!/usr/bin/env bash
set -eo pipefail

test "$(gh api "repos/$GITHUB_REPOSITORY/commits/$TAG" --jq .sha)" = "$(cat commit)"
sha256sum --check SHA256SUMS
asset="swm-${TAG#v}.arm64_golden_gate.bottle.tar.gz"
digest="sha256:$(sha256sum "$asset" | cut -d ' ' -f 1)"

if ! gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null; then
  notes=(--generate-notes)
  if [[ -f previous-tag ]]; then
    notes+=(--notes-start-tag "$(cat previous-tag)")
  fi
  if [[ -f notes.md ]] && grep -q '[^[:space:]]' notes.md; then
    notes=(--notes-file notes.md)
  fi
  gh release create "$TAG" --repo "$GITHUB_REPOSITORY" --verify-tag --title "$TAG" \
    --draft --prerelease --latest=false "${notes[@]}"
fi

release=$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,isPrerelease,assets)
jq -e '.isPrerelease' <<<"$release"
if ! jq -e --arg asset "$asset" 'any(.assets[]; .name == $asset)' <<<"$release"; then
  # A published release must already have the tested asset.
  jq -e '.isDraft' <<<"$release"
  gh release upload "$TAG" "$asset" --repo "$GITHUB_REPOSITORY"
fi
gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json assets |
  jq -e --arg asset "$asset" --arg digest "$digest" \
    'any(.assets[]; .name == $asset and .state == "uploaded" and .digest == $digest)'
if jq -e '.isDraft' <<<"$release" >/dev/null; then
  gh release edit "$TAG" --repo "$GITHUB_REPOSITORY" --draft=false --latest=false
fi
gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,isPrerelease,url |
  jq -er 'select(.isDraft == false and .isPrerelease) | .url'
if [[ -z "$TAP_APP_CLIENT_ID" ]]; then
  echo '::warning::The tap PR requires HOMEBREW_TAP_APP_CLIENT_ID and HOMEBREW_TAP_APP_PRIVATE_KEY. The tested swm.rb is in the swm-release artifact.'
fi
