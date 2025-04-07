module.exports = {
    "endpoint": "http://your-forgejo-instance:3000/api/v1", // Update with your actual Forgejo endpoint
    "gitAuthor": "Renovate Bot <renovate-bot@example.com>", // Update with your preferred email
    "platform": "gitea",
    "onboardingConfigFileName": "renovate.json5",
    "autodiscover": true,
    "autodiscoverFilter": ["*/*"], // Adjust filter as needed for your repositories
    "optimizeForDisabled": true,
    "forkProcessing": "disabled",
    "dryRun": null,
    "binarySource": "install",
    "hostRules": [
        {
            "matchHost": "docker.io",
            "username": process.env.HUB_DOCKER_COM_USER,
            "password": process.env.HUB_DOCKER_COM_TOKEN
        }
    ],
    "allowedPostUpgradeCommands": [
        "install-tool node",
        "make readme"
    ]
};
