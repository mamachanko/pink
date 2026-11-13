cask "pink" do
  version "1.0.2"
  sha256 "605a7bf702ea7039a02f9fceab39f79b4c81b85a838f602f27866015bbe8c521"

  url "https://github.com/mamachanko/pink/releases/download/v#{version}/Pink-#{version}-adhoc.dmg"
  name "Pink"
  desc "Local menu-bar formatter for short GitHub and GitLab hyperlinks"
  homepage "https://github.com/mamachanko/pink"

  depends_on macos: ">= :sequoia"

  app "Pink.app"

  zap trash: [
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
