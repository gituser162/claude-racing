# Claude Racing — для Claude

Аркадні 3D-перегони на Godot 4.7 (GDScript, Compatibility, Jolt). Увесь код і контент робить Claude, автор дає завдання й тестує. Спілкування й коментарі — українською.

Перед роботою прочитай:
1. `DESIGN.md` — ідея гри, правила (зокрема **збірки лише за вказівкою автора**), гонщики, мапи, стиль графіки.
2. `docs/TECH_NOTES.md` — як працювати з папкою автора, архітектура, підводні камені Godot.
3. За потреби: `docs/ADDING_RACERS.md`, `docs/ADDING_MAPS.md`, `tools/tests/README.md`.

Після кожної зміни: перевірити (тести з `tools/tests/`), оновити `DESIGN.md`, записати в папку автора (stage → diff → запис з `expectedMtimeMs`), комміт і push у `main`.
