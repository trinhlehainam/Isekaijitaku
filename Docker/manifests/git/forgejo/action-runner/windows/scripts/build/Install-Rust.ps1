# Ref: https://github.com/actions/runner-images/blob/main/images/windows/scripts/build/Install-Rust.ps1

param (
    [string]$InstallPath
)

$env:RUSTUP_HOME = Join-Path $InstallPath ".rustup"
$env:CARGO_HOME = Join-Path $InstallPath ".cargo"

# Download the latest rustup-init.exe for Windows x64
# See https://rustup.rs/#
$rustupPath = Invoke-DownloadWithRetry "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"

#region Supply chain security
$distributorFileHash = (Invoke-RestMethod -Uri 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe.sha256').Trim()
Test-FileChecksum $rustupPath -ExpectedSHA256Sum $distributorFileHash
#endregion

# Install Rust by running rustup-init.exe (disabling the confirmation prompt with -y)
& $rustupPath -y --default-toolchain=stable --profile=minimal
if ($LASTEXITCODE -ne 0) {
    throw "Rust installation failed with exit code $LASTEXITCODE"
}

# Add Rust binaries to the path
$env:Path += ";$env:CARGO_HOME\bin"

# Add i686 target for building 32-bit binaries
rustup target add i686-pc-windows-msvc

# Add target for building mingw-w64 binaries
rustup target add x86_64-pc-windows-gnu

# Install common tools
rustup component add rustfmt clippy
if ($LASTEXITCODE -ne 0) {
    throw "Rust component installation failed with exit code $LASTEXITCODE"
}
if (-not (Test-IsWin25)) {
    cargo install bindgen-cli cbindgen cargo-audit cargo-outdated
    if ($LASTEXITCODE -ne 0) {
        throw "Rust tools installation failed with exit code $LASTEXITCODE"
    }
    # Cleanup Cargo crates cache
    Remove-Item "${env:CARGO_HOME}\registry\*" -Recurse -Force
}

# Remove rustup-init.exe
Remove-Item $rustupPath