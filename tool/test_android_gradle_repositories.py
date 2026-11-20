import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ensure_android_maven_central import ensure_maven_central


class TestAndroidGradleRepositories(unittest.TestCase):
    def test_adds_maven_central_before_the_plugin_portal(self):
        source = """pluginManagement {
    includeBuild("flutter/gradle")
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}
"""
        updated, changed = ensure_maven_central(source)
        self.assertTrue(changed)
        self.assertLess(updated.index("mavenCentral()"), updated.index("gradlePluginPortal()"))
        self.assertIn("google()", updated)

    def test_adds_repositories_when_plugin_management_has_no_repository_block(self):
        source = """pluginManagement {
    val flutterSdkPath = "/opt/flutter"
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}
"""
        updated, changed = ensure_maven_central(source)
        self.assertTrue(changed)
        self.assertIn("repositories {", updated)
        self.assertIn("mavenCentral()", updated)

    def test_preserves_existing_repositories_and_is_idempotent(self):
        source = """pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
"""
        updated, changed = ensure_maven_central(source)
        self.assertFalse(changed)
        self.assertEqual(updated, source)

    def test_adds_maven_central_to_dependency_resolution_when_missing(self):
        source = """pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
    }
}
"""
        updated, changed = ensure_maven_central(source)
        self.assertTrue(changed)
        self.assertEqual(updated.count("mavenCentral()"), 2)


if __name__ == "__main__":
    unittest.main()
