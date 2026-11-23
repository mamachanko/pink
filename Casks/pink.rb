cask "pink" do
  version "1.7.0"
  sha256 "c034224ac8ce7d522d81ae67a166d578464989328101810680b2d9670998005e"

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
