[ ] Failed to setup Pty Unsupported when using actions/setup-node@v3 on Windows runner
[ ] Failed to setup-python@v5 with error: symlink ..\poetry.lock C:\ProgramData\GiteaActRunner\.cache\act\8dd8b1aead80a801f9b34ee6d45c001ae20a6c2abfe4c7037c4803578f162558\__tests__\data\inner\poetry.lock: Access is denied.
    - https://github.com/actions/setup-python/blob/main/docs/advanced-usage.md#windows
    - https://github.com/actions/setup-python/issues/600
[ ] actions/checkout fatal: detected dubious ownership in repository cause when ownership of .cache folder change when docker container is recreated