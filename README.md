# Toxic Rain

Отдельный Roblox-проект кооперативной survival-игры **Toxic Rain**. Игроки
движутся вперёд по заражённой территории, ищут укрытия от токсичного дождя и
не дают приближающейся буре себя догнать.

Основной дизайн и ограничения проекта описаны в
[`TOXIC RAIN — GDD И ТЕХНИЧЕСКИЕ ПРАВИЛА ПРОЕКТА.md`](TOXIC%20RAIN%20%E2%80%94%20GDD%20%D0%98%20%D0%A2%D0%95%D0%A5%D0%9D%D0%98%D0%A7%D0%95%D0%A1%D0%9A%D0%98%D0%95%20%D0%9F%D0%A0%D0%90%D0%92%D0%98%D0%9B%D0%90%20%D0%9F%D0%A0%D0%9E%D0%95%D0%9A%D0%A2%D0%90.md).
Фактическое состояние сцены и результаты последней проверки записаны в
[`docs/PrototypeStatus.md`](docs/PrototypeStatus.md).

## Локальный запуск

1. Установите инструменты проекта: `rokit install`.
2. Запустите проверенный Rojo-сервер:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ensure-rojo-server.ps1`.
3. Откройте канонический `place.rbxl` в Roblox Studio.
4. Подключите плагин Rojo к стандартному адресу `127.0.0.1:34872`; имя
   подключения должно быть `rain`.

Для проверки текстовой сборки используйте:

```powershell
rojo build default.project.json --output $env:TEMP\toxic-rain-validation.rbxlx
```

## Разработка игровых фич

Начните с [пошаговой инструкции](docs/FeatureDevelopmentForBeginners.md).
Проектные фичи хранятся в `docs/Features/project/`; история шаблона в
`docs/Features/template/` доступна только для чтения.

## Обновление основы

Шаблон подключён как `upstream`. Перед обновлением следуйте
`.agents/rules/template-workflow.md`; проектный `place.rbxl`,
`src/ReplicatedStorage/Project/`, `docs/Features/project/` и
`docs/adr/project/` сохраняются как защищённые данные проекта.

Исходный шаблон: [teano/roblox_project_template](https://github.com/teano/roblox_project_template).
