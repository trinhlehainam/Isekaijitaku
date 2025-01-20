# Example Actions for Windows Runner

This directory contains sample GitHub Actions workflows that demonstrate various use cases for the Windows runner. These workflows can be used as templates for your own projects.

## Available Workflows

### 1. Environment Test (`environment-test.yaml`)
- Tests the runner environment and installed tools
- Generates a detailed report of the system
- Runs on schedule or manual trigger
- Verifies all required tools are properly installed
- Tests ImageHelpers module functions:
  - Validates module import and available functions
  - Tests InstallHelpers functions (download, checksum, environment updates)
  - Tests UnityInstallHelpers functions (paths and version management)
  - Tests VisualStudioHelpers functions (instance and package management)
- Generates comprehensive JSON report including module status

### 2. .NET Test (`dotnet-test.yaml`)
- Basic .NET build and test workflow
- Includes restore, build, test, and publish steps
- Demonstrates artifact upload

### 3. Unity Test (`unity-test.yaml`)
- Complete Unity project build and test workflow
- Includes PlayMode tests
- Uses Unity cache for faster builds
- Handles Unity license activation
- Uploads test results and build artifacts

### 4. Rust Test (`rust-test.yaml`)
- Comprehensive Rust project workflow
- Includes formatting check (rustfmt)
- Runs clippy for linting
- Performs testing and building
- Uses Rust toolchain caching
- Cross-compilation support for Windows
- Enhanced target testing:
  - Lists all available and installed targets
  - Tests each installed target individually:
    - Verifies target-specific environment variables
    - Checks toolchain compatibility (MSVC/GNU)
    - Validates compilation and execution
    - Tests native CPU optimizations
  - Validates target-specific tools (cl.exe, link.exe, gcc.exe)
  - Performs test compilation for each target

### 5. Node.js Test (`node-test.yaml`)
- Node.js project workflow with native modules
- Includes linting and type checking
- Runs tests and builds
- Handles npm package creation
- Uses npm caching

### 6. Visual C++ Test (`cpp-test.yaml`)
- Visual Studio C++ project workflow
- Builds for multiple configurations (Debug/Release)
- Supports multiple platforms (x64/x86)
- Includes VSTest integration
- Uses NuGet package caching

### 7. Common Actions Test (`common-actions-test.yaml`)
- Tests essential GitHub Actions
- Validates `actions/checkout@v4`
- Tests `actions/setup-node@v4`
- Tests `actions/setup-python@v5`
- Demonstrates artifact upload/download using `actions/upload-artifact@v3` and `actions/download-artifact@v3`
- Tests caching with `actions/cache@v3`
- Verifies environment variables and runner context

## Usage

1. Copy the desired workflow file to your repository's `.gitea/workflows/` directory
2. Modify the workflow as needed for your project
3. Commit and push to trigger the workflow

## Environment Variables

Some workflows may require setting up secrets in your repository:

- Unity workflow:
  - `UNITY_LICENSE`
  - `UNITY_EMAIL`
  - `UNITY_PASSWORD`

## Notes

- All workflows are configured to run on the `windows` runner
- Cache actions are used where appropriate to speed up builds
- Artifacts are uploaded for build outputs
- Tests are included in all workflows where applicable

## Best Practices

1. Always use appropriate caching:
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.nuget/packages
       key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.sln') }}
   ```

2. Use matrix builds for multiple configurations:
   ```yaml
   strategy:
     matrix:
       configuration: [Debug, Release]
       platform: [x64, x86]
   ```

3. Upload artifacts for build outputs:
   ```yaml
   - uses: actions/upload-artifact@v3
     with:
       name: build-output
       path: ./build
   ```

4. Handle environment setup properly:
   ```yaml
   - name: Setup Environment
     uses: actions/setup-dotnet@v3
     with:
       dotnet-version: '7.0.x'
   ```

## Testing

To test these workflows:

1. Environment Test:
   ```bash
   gitea act workflow_dispatch -W examples/actions/environment-test.yaml
   ```

2. Specific Project Test:
   ```bash
   gitea act push -W examples/actions/dotnet-test.yaml
   ```
