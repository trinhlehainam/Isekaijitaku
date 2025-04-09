module.exports = {
    "endpoint": "http://forgejo:3000/api/v1", // Update with your actual Forgejo endpoint
    // "endpoint": "https://your-forgejo-domain/api/v1", // Update with your actual Forgejo endpoint
    "gitAuthor": "Renovate Bot <renovate-bot@example.com>", // Update with your preferred email
    "platform": "gitea",
    "onboardingConfigFileName": "renovate.json5",
    "autodiscover": true,
    "autodiscoverFilter": ["*/*"], // Adjust filter as needed for your repositories
    "optimizeForDisabled": true,
    "forkProcessing": "disabled",
    "dryRun": null,
    "binarySource": "install",
    "allowedCommands": [
        "install-tool node",
        "make readme"
    ]
};
