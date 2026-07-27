# Homebrew formula for Yard Dog (Apple Silicon).
# Install directly from the raw URL, or from a `homebrew-yard-dog` tap:
#   brew install https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/packaging/homebrew/yd.rb
# Keep `version`, `url`, and `sha256` in step with the matching GitHub release.
class Yd < Formula
  desc "Single-host Docker Compose manager with mount intelligence and verified backup"
  homepage "https://github.com/williamweatherholtz/yard_dog"
  version "0.1.3"
  license "AGPL-3.0-or-later"

  on_macos do
    on_arm do
      url "https://github.com/williamweatherholtz/yard_dog/releases/download/v#{version}/yd-aarch64-macos"
      sha256 "609cbc6384afe7b01d06eb35a0eb1f452733e4ef47bb4f9824a5bfacecaaa10b"
    end
    # Intel (x86_64) macOS build is not published yet (its CI runner queues
    # unreliably); on an Intel Mac, install a release binary manually for now.
  end

  def install
    bin.install "yd-aarch64-macos" => "yd"
  end

  test do
    system "#{bin}/yd", "--help"
  end
end
