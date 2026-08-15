# kufar-posting

> 🇷🇺 [Русская версия](README.ru.md)

The team's repository. Inside are the packages, each in its own folder.

A folder's name matches the package's identity in the registry (`kufar.Name`) —
a SwiftPM requirement: Xcode uses it to substitute a local copy from the
workspace for the dependency. Rename the folder and the substitution silently
switches off.

Packages are released independently, with tags prefixed by the name:
`kufar.Foundation-1.2.0`.
