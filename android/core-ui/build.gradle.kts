plugins { id("com.android.library"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "ai.chatty.core.ui"
    compileSdk = 35
    defaultConfig { minSdk = 26 }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.15" }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    api("androidx.compose.material3:material3")
    api("androidx.compose.material:material-icons-extended")
}
