# Stack research — 2026-10-23
Sources: опыт сборки Jump Square в этой сессии; godotengine.org/download (4.7.2 stable).
- Godot 4.7.2 экспортирует Android APK headless без Gradle (шаблоны android_debug/release.apk).
- Требуется: export templates 4.7.2, Android SDK build-tools 35 + platform 35, JDK 17+ (есть 21), debug keystore (Godot генерирует сам).
- Unity/Unreal: нужны GUI, логины и лицензии — неприменимо в облаке без экрана.
- Вывод: Godot 4.7.2, GL Compatibility, вертикальная ориентация.
