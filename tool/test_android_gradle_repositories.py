import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ensure_android_maven_central import ensure_maven_central


class TestAndroidGradleRepositories(unittest.TestCase):
    def test_adds_maven_central_before_the_plugin_portal(self):
        source = """pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
    }
}
"""
        updated, changed = ensure_maven_central(source)
        self.assertTrue(changed)
        self.assertLess(updated.index("mavenCentral()"), updated.index("gradlePluginPortal()"))

    def test_preserves_existing_maven_central_and_is_idempotent(self):
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

    def test_fails_closed_when_plugin_repository_block_is_missing(self):
        with self.assertRaises(ValueError):
            ensure_maven_central("rootProject.name = \"test\"")


if __name__ == "__main__":
    unittest.main()
