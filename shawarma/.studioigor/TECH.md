# Technology — Шаурмичная

ENGINE: godot
ENGINE VERSION: 4.7.2
DIMENSION: 3D
LANGUAGE: GDScript
PLATFORMS: Android (.apk, arm64-v8a + armeabi-v7a), альбомная ориентация (3D); 2D-версия — вертикальная

## Decision
- context: 2D-симулятор под телефон, пользователь только с телефона, сборка в облачном Linux без GUI.
- options: Godot — headless-экспорт APK, текстовые сцены, бесплатно / ничего; Unity — нужен GUI, лицензия, логин; Web (HTML5) — открывается в браузере, но не .apk.
- choice and why: Godot 4.7.2 — пользователь выбрал «движок + .apk» в начале разговора; цепочка проверена на Jump Square.
- consequences: вся графика процедурная (_draw, полигоны), без внешних текстур; рендер GL Compatibility для слабых телефонов.

## Budgets
60 fps на среднем телефоне при 3 клиентах и 3 шаурмах на гриле; APK ≤ 60 МБ.

## Project structure
- scripts/ — логика (main, станции, клиенты, UI, рисование)
- data/balance.json — все числа баланса
- scenes/ — main.tscn
- assets/fonts, assets/sfx
- tests/ — только формулы оплаты/оценки заказа
