pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "kreta-ora"

// The pure Kotlin core is its own build, so its tests run without the Android
// SDK. The app's "hu.kretaora:core" dependency is substituted by this build.
includeBuild("core")
include(":app")
