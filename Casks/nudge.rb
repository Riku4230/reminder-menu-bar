cask "nudge" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/Riku4230/Nudge/releases/download/v#{version}/Nudge-v#{version}.dmg",
      verified: "github.com/Riku4230/Nudge/"
  name "Nudge"
  desc "Menu bar app for Apple Reminders with AI mode"
  homepage "https://github.com/Riku4230/Nudge"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  app "Nudge.app"

  zap trash: [
    "~/Library/Preferences/dev.remindermenu.app.plist",
    "~/Library/Application Support/Nudge",
    "~/Library/Caches/dev.remindermenu.app",
  ]

  caveats <<~EOS
    Nudge は未署名で配布されています。初回起動時に Gatekeeper 警告が出たら：
      システム設定 → プライバシーとセキュリティ → 「このまま開く」

    リマインダーへのフルアクセスとフルディスクアクセスはアプリ内ウィザードから案内されます。
  EOS
end
