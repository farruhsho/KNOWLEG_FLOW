@echo off
REM Обновляем PATH для включения NuGet
set PATH=%PATH%;C:\Users\Farruh;C:\project\project1\knowledge_flow
echo Запускаем Flutter приложение на Windows...
echo NuGet location: C:\Users\Farruh\nuget.exe
flutter run -d windows
