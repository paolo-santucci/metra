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
subprojects {
    project.evaluationDependsOn(":app")
}

// Bump compileSdk on library subprojects after each one is configured.
// sqlcipher_flutter_libs hardcodes compileSdkVersion 28; lStar (API 31) is needed.
gradle.afterProject {
    extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
        if (compileSdk != null && compileSdk!! < 36) compileSdk = 36
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
