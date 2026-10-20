cask "fanbar" do
  version "0.6.3"
  sha256 "6f0ac67581397c511661b6e38610fa7a9af5a5d6a7a1635da3d013b626ea426c"

  url "https://github.com/helson-lin/FanBar/releases/download/v#{version}/FanBar-#{version}.dmg"
  name "FanBar"
  desc "Menu bar temperature monitor and fan controller"
  homepage "https://github.com/helson-lin/FanBar"

  auto_updates true
  depends_on :macos

  app "FanBar.app"

  uninstall launchctl: ["local.fanbar.app", "local.fanbar.helper", "local.fanbar.helper.plist"],
            quit:      "local.fanbar.app",
            delete:    "~/Library/LaunchAgents/local.fanbar.app.plist"

  zap trash: [
    "~/Library/Caches/local.fanbar.app",
    "~/Library/Preferences/local.fanbar.app.plist",
    "~/Library/Saved Application State/local.fanbar.app.savedState",
  ]
end
