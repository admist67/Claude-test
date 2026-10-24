# Stack research — 2026-10-24
Sources: https://80.lv/articles/godot-4-7-has-been-released · https://gamedev.net/news/3712-creating-games-entirely-on-android/ · ../shawarma/.studioigor/ENV.md (проверенный опыт в этом репо)

- Godot 4.7 (июнь 2026), патч 4.7.2 — стабильный; Android-экспорт без Gradle работает из CLI, проверено на «Шаурма Шеф 3D».
- Рендерер gl_compatibility — самый широкий охват Android-устройств; хватает для low-poly + свой шейдер воды.
- Готовые океаны (Forward+ GPU-океаны, Ocean3D) — требуют desktop GPU или платные. Берём свой шейдер: сумма 3–4 волн Гerstner/синусов в vertex, та же функция в GDScript для плавучести (как у Ocean3D — «одна функция для шейдера и физики»).
- Альтернативы: Unity (тяжелее для агента в облаке, нужен логин), Unreal (тяжело для мобилок), Defold (слабый 3D).
- Вывод: Godot 4.7.2 + GDScript, 3D, Compatibility, Android APK. Пользователь уже выбрал Godot.
