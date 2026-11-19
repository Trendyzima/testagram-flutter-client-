from pathlib import Path
import re
import sys


def ensure_maven_central(source: str) -> tuple[str, bool]:
    changed = False
    for block_name in ("pluginManagement", "dependencyResolutionManagement"):
        pattern = re.compile(
            rf"({block_name}\s*\{{\s*repositories\s*\{{)(.*?)(\})",
            re.DOTALL,
        )
        match = pattern.search(source)
        if match is None:
            if block_name == "pluginManagement":
                raise ValueError("Android settings.gradle.kts has no pluginManagement.repositories block")
            continue
        body = match.group(2)
        if re.search(r"\bmavenCentral\s*\(\s*\)", body):
            continue
        if "gradlePluginPortal()" in body:
            body = body.replace(
                "gradlePluginPortal()",
                "mavenCentral()\n        gradlePluginPortal()",
                1,
            )
        else:
            body = body.rstrip() + "\n        mavenCentral()\n"
        source = source[: match.start(2)] + body + source[match.end(2) :]
        changed = True
    return source, changed


def main() -> int:
    settings = Path("android/settings.gradle.kts")
    if not settings.is_file():
        print("::error::Flutter Android settings.gradle.kts was not generated.")
        return 1
    original = settings.read_text(encoding="utf-8")
    updated, changed = ensure_maven_central(original)
    if changed:
        settings.write_text(updated, encoding="utf-8")
        print("Added Maven Central to Android Gradle plugin/dependency repositories.")
    else:
        print("Android Gradle settings already include Maven Central.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
