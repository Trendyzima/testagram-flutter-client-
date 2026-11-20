from pathlib import Path
import os
import re
import sys


def _ensure_section_repositories(source: str, section: str, required: tuple[str, ...]) -> tuple[str, bool]:
    section_pattern = re.compile(r"(?m)^\s*" + re.escape(section) + r"\s*\{")
    section_match = section_pattern.search(source)
    if section_match is None:
        if section != "pluginManagement":
            return source, False
        block = (
            "pluginManagement {\n"
            "    repositories {\n"
            "        google()\n"
            "        mavenCentral()\n"
            "        gradlePluginPortal()\n"
            "    }\n"
            "}\n\n"
        )
        return block + source, True

    if section == "pluginManagement":
        section_end = source.find("\nplugins {", section_match.end())
        if section_end < 0:
            section_end = len(source)
    else:
        section_end = len(source)
    block = source[section_match.start():section_end]
    repositories_pattern = re.compile(r"repositories\s*\{(.*?)\}", re.DOTALL)
    repositories_match = repositories_pattern.search(block)
    if repositories_match is None:
        insertion = (
            "\n    repositories {\n"
            + "".join(f"        {repository}()\n" for repository in required)
            + "    }\n"
        )
        position = section_match.end()
        return source[:position] + insertion + source[position:], True

    body = repositories_match.group(1)
    missing = [
        repository
        for repository in required
        if re.search(r"\b" + re.escape(repository) + r"\s*\(", body) is None
    ]
    if not missing:
        return source, False
    additions = "".join(f"        {repository}()\n" for repository in missing)
    if "gradlePluginPortal()" in body and "gradlePluginPortal" in missing:
        updated_body = body.replace("gradlePluginPortal()", additions + "        gradlePluginPortal()", 1)
    else:
        updated_body = body.rstrip() + "\n" + additions.rstrip("\n") + "\n"
    start = section_match.start() + repositories_match.start(1)
    end = section_match.start() + repositories_match.end(1)
    return source[:start] + updated_body + source[end:], True


def ensure_maven_central(source: str) -> tuple[str, bool]:
    changed = False
    source, updated = _ensure_section_repositories(
        source, "pluginManagement", ("google", "mavenCentral", "gradlePluginPortal")
    )
    changed = changed or updated
    source, updated = _ensure_section_repositories(
        source, "dependencyResolutionManagement", ("google", "mavenCentral")
    )
    changed = changed or updated
    return source, changed


def _ensure_settings_file(settings: Path, label: str) -> int:
    if not settings.is_file():
        print(f"::error::{label} settings.gradle.kts was not found: {settings}")
        return 1
    original = settings.read_text(encoding="utf-8")
    updated, changed = ensure_maven_central(original)
    if changed:
        settings.write_text(updated, encoding="utf-8")
        print(f"Ensured plugin and dependency repositories in {label} Gradle settings.")
    else:
        print(f"{label} Gradle settings already include the required repositories.")
    return 0


def main() -> int:
    android_settings = Path("android/settings.gradle.kts")
    flutter_root = os.environ.get("FLUTTER_ROOT", "").strip()
    if not flutter_root:
        print("::error::FLUTTER_ROOT is not set; cannot verify the Flutter Gradle included build.")
        return 1
    flutter_included_build_settings = (
        Path(flutter_root) / "packages" / "flutter_tools" / "gradle" / "settings.gradle.kts"
    )
    for settings, label in (
        (android_settings, "Android app"),
        (flutter_included_build_settings, "Flutter included build"),
    ):
        if _ensure_settings_file(settings, label) != 0:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
