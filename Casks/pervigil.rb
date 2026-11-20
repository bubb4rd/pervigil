# Homebrew Cask for Pervigil.
#
# This lives here as the source of truth. To make `brew install --cask pervigil`
# work, publish it to the tap repo `bubb4rd/homebrew-tap` (a GitHub repo with
# this file under `Casks/`), after which:
#
#   brew install --cask bubb4rd/tap/pervigil
#
# Per release: bump `version` and set `sha256` to the DMG's hash
#   (shasum -a 256 dist/Pervigil-<version>.dmg), then commit to the tap.
# The `livecheck` block lets `brew livecheck` notice new GitHub releases.
cask "pervigil" do
  version "2.0.0"
  sha256 "9eed664a5bb48369d56e2bb44a1675bc8f3f6f744180aae2d722380080af58e9"

  url "https://github.com/bubb4rd/pervigil/releases/download/v#{version}/Pervigil-#{version}.dmg"
  name "Pervigil"
  desc "Menu-bar keep-awake app with triggers, timed sessions, and closed-display mode"
  homepage "https://github.com/bubb4rd/pervigil"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true # Pervigil updates itself via Sparkle
  depends_on macos: :sonoma

  app "Pervigil.app"
  # The caffeinate-style CLI, embedded in the app bundle (Contents/Helpers).
  binary "#{appdir}/Pervigil.app/Contents/Helpers/pervigil"

  zap trash: [
    "~/Library/Application Support/Pervigil",
    "~/Library/Caches/io.github.bubb4rd.pervigil",
    "~/Library/Group Containers/*.io.github.bubb4rd.pervigil",
    "~/Library/Preferences/io.github.bubb4rd.pervigil.plist",
  ]
end
