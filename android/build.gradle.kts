import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// biometric_storage 5.0.1 pins compileSdk 31, while its resolved AndroidX
// dependencies require newer APIs. Use AGP's final DSL hook rather than editing
// the downloaded plugin or changing the app's minimum supported Android version.
subprojects {
    if (name == "biometric_storage") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryAndroidComponentsExtension> {
                finalizeDsl { library -> library.compileSdk = 36 }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
