pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "Chatty"
include(":app", ":core-model", ":core-network", ":core-auth", ":feature-chat", ":feature-status", ":feature-approval", ":feature-inbox", ":feature-agents", ":feature-issue-link")

include(":feature-workspace")

include(":core-ui")
