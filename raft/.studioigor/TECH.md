# Technology — Плот

<!-- Phase 3 (references/stack.md). ENGINE — one of: godot, godot-mono, unity,
unreal, web, defold, bevy (read by studio.py and envcheck.py). DIMENSION — 2D or 3D
(2.5D with 3D models is 3D); envcheck.py recommends Blender for 3D. -->
ENGINE: godot
ENGINE VERSION: 4.7.2
DIMENSION: 3D
LANGUAGE: GDScript
PLATFORMS: Android (телефон, горизонтально)

## Decision
- context: 3D-выживание от 1-го лица на телефоне, low-poly, вода с волнами и плавучестью
- options: Godot — бесплатно, CLI-экспорт APK из облака, уже освоен в репо / нет готового мобильного океана; Unity — богатый Asset Store / логин, тяжёлый в облаке; Unreal — мощно / тяжело для мобилок
- choice and why: Godot 4.7.2 — выбор пользователя; проверен на «Шаурма Шеф 3D»
- consequences: свой шейдер воды + та же функция высоты в GDScript; модели CC0 (Kenney/Quaternius) или процедурные; рендерер gl_compatibility

## Budgets
60 fps на среднем Android (30 минимум) при 40 предметах в воде и плоту 6×6; ≤150 draw calls; APK ≤ 80 МБ

## Project structure
scenes/ — сцены (main.tscn); scripts/ — логика; data/*.json — баланс, предметы, рецепты; assets/ — модели, звуки; tools/ — бот кадров и генераторы; tests/ — тесты чистой логики
