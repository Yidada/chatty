plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.kapt")
    id("com.google.dagger.hilt.android")
}
val fixture = providers.gradleProperty("chattyFixture").orNull == "true"
// Measurement-only knob: points the benchmark build at a designated test service so
// DNS/TLS/TTFB can be captured. Defaults to the synthetic loopback fixture.
val benchmarkBaseUrl = providers.gradleProperty("chattyBenchmarkBaseUrl").getOrElse("http://127.0.0.1:8765/")
android {
    namespace = "ai.chatty.app"
    compileSdk = 35
    defaultConfig {
        applicationId = "ai.chatty.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.2.0-dev"
    }
    buildTypes {
        debug {
            applicationIdSuffix = if (fixture) ".fixture" else ".debug"
            buildConfigField("String", "API_BASE_URL", if (fixture) "\"http://127.0.0.1:8765/\"" else "\"https://api.multica.ai/\"")
            resValue("string", "app_name", if (fixture) "Chatty Test" else "Chatty")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "API_BASE_URL", "\"https://api.multica.ai/\"")
            resValue("string", "app_name", "Chatty")
        }
    }
    buildTypes.create("benchmark") {
        initWith(buildTypes.getByName("release"))
        applicationIdSuffix = ".benchmark"
        isDebuggable = false
        signingConfig = signingConfigs.getByName("debug")
        matchingFallbacks += listOf("release")
        buildConfigField("String", "API_BASE_URL", "\"$benchmarkBaseUrl\"")
        resValue("string", "app_name", "Chatty Benchmark")
    }
    buildFeatures { compose = true; buildConfig = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.15" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
kapt { correctErrorTypes = true }
dependencies {
    implementation(project(":core-ui"))
    implementation(project(":core-model"))
    implementation(project(":core-network"))
    implementation(project(":core-auth"))
    implementation(project(":feature-chat"))
    implementation(project(":feature-workspace"))
    implementation(project(":feature-status"))
    implementation(project(":feature-approval"))
    implementation(project(":feature-inbox"))
    implementation(project(":feature-agents"))
    implementation(project(":feature-issue-link"))
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.9.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.4")
    implementation("com.google.dagger:hilt-android:2.51.1")
    kapt("com.google.dagger:hilt-compiler:2.51.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
