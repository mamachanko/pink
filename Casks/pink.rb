cask "pink" do
  version "1.5.0"
  sha256 "abd271d67ef583a6d40b0a412ba79455bc55b103da913dbb59b156cf67df80ca"

  url "https://github.com/mamachanko/pink/releases/download/v#{version}/Pink-#{version}-adhoc.dmg"
  name "Pink"
  desc "Local menu-bar formatter for short GitHub and GitLab hyperlinks"
  homepage "https://github.com/mamachanko/pink"

  depends_on macos: :sequoia

  app "Pink.app"

  zap trash: [
    "~/Library/Caches/io.github.mamachanko.pink",
    "~/Library/Preferences/io.github.mamachanko.pink.plist",
    "~/Library/Preferences/io.refpaste.app.plist",
  ]

  caveats <<~EOS
    Ad-hoc signed; not Developer ID signed; not notarized.
    Open Pink explicitly after installation and approve clipboard processing.
    macOS may require per-app approval in Privacy & Security.
    Disable launch at login and quit Pink before uninstalling.
  EOS
end
