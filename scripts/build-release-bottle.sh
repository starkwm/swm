#!/usr/bin/env bash
set -eo pipefail

version=${TAG#v}
cd "$RUNNER_TEMP/swm-release"
brew tap "$TAP"
formula="$(brew --repository "$TAP")/Formula/swm.rb"
git hash-object "$formula" >tap-formula-base
source_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/archive/refs/tags/$TAG.tar.gz"
curl --fail --silent --show-error --location --retry 3 "$source_url" --output "$RUNNER_TEMP/swm-source.tar.gz"
source_sha=$(shasum -a 256 "$RUNNER_TEMP/swm-source.tar.gz" | cut -d ' ' -f 1)

ruby - "$formula" "$version" "$source_sha" <<'RUBY'
path, version, checksum = ARGV
formula = File.read(path)
version_line = /^  version '[^']+'$/
checksum_line = /^  sha256 '[0-9a-f]{64}'$/
bottle_block = /^  bottle do\n.*?^  end\n\n/m
abort 'Unexpected swm formula layout' unless formula.scan(version_line).one? &&
  formula.scan(checksum_line).one? && formula.scan(bottle_block).one? &&
  formula.include?('url "https://github.com/starkwm/swm/archive/refs/tags/v#{version}.tar.gz"')
File.write(path, formula.sub(version_line, "  version '#{version}'")
                        .sub(checksum_line, "  sha256 '#{checksum}'")
                        .sub(bottle_block, ''))
RUBY

brew install --build-bottle "$TAP/swm"
root_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$TAG"
brew bottle --no-rebuild --json --root-url "$root_url" "$TAP/swm"
metadata="swm--$version.arm64_golden_gate.bottle.json"
bottle="$PWD/swm--$version.arm64_golden_gate.bottle.tar.gz"
bottle_sha=$(shasum -a 256 "$bottle" | cut -d ' ' -f 1)
jq -e --arg sha "$bottle_sha" \
  '.["starkwm/formulae/swm"].bottle.tags.arm64_golden_gate.sha256 == $sha' "$metadata"
brew bottle --merge --write --no-commit "$metadata"
cp "$formula" swm.rb

brew uninstall "$TAP/swm"
# Homebrew removes formula trust on uninstall.
brew trust --formula "$TAP/swm"
HOMEBREW_DEVELOPER=1 brew install "$bottle"
brew info --json=v2 "$TAP/swm" | jq -e --arg version "$version" \
  'any(.formulae[0].installed[]; .version == $version and .poured_from_bottle)'
brew test "$TAP/swm"

asset="swm-$version.arm64_golden_gate.bottle.tar.gz"
mv "$bottle" "$asset"
printf '%s  %s\n' "$bottle_sha" "$asset" >SHA256SUMS
