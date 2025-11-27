# PowerShell script to remove unused imports
$files = @(
    "lib\features\admin\presentation\pages\admin_dashboard_page.dart",
    "lib\features\admin\presentation\pages\ai_generator_page.dart",
    "lib\features\dashboard\presentation\pages\dashboard_page.dart",
    "lib\features\handbook\presentation\pages\handbook_content_page.dart",
    "lib\features\lessons\presentation\pages\lesson_page.dart",
    "lib\features\progress\presentation\pages\progress_page.dart",
    "lib\features\subjects\presentation\pages\subject_detail_page.dart",
    "lib\features\subjects\presentation\pages\subjects_list_page.dart",
    "lib\shared\models\ort_test_model.dart",
    "test\widget_test.dart"
)

$removals = @{
    "lib\features\admin\presentation\pages\admin_dashboard_page.dart" = "import '../../../../core/theme/app_colors.dart';"
    "lib\features\admin\presentation\pages\ai_generator_page.dart" = @("import '../../../../shared/services/firebase_data_service.dart';", "import '../../../../shared/widgets/loading_view.dart';")
    "lib\features\dashboard\presentation\pages\dashboard_page.dart" = "import '../../../../core/constants/app_constants.dart';"
    "lib\features\handbook\presentation\pages\handbook_content_page.dart" = @("import 'package:go_router/go_router.dart';", "import '../../../../core/theme/app_colors.dart';")
    "lib\features\lessons\presentation\pages\lesson_page.dart" = "import 'package:go_router/go_router.dart';"
    "lib\features\progress\presentation\pages\progress_page.dart" = "import '../../../../shared/widgets/animations.dart';"
    "lib\features\subjects\presentation\pages\subject_detail_page.dart" = @("import '../../../../core/routes/app_router.dart';", "import '../../../../shared/models/subject_model.dart';")
    "lib\features\subjects\presentation\pages\subjects_list_page.dart" = @("import '../../../../core/routes/app_router.dart';", "import '../../../../core/theme/app_colors.dart';")
    "lib\shared\models\ort_test_model.dart" = "import 'question_model.dart';"
    "test\widget_test.dart" = "import 'package:flutter/material.dart';"
}

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        $imports = $removals[$file]
        
        if ($imports -is [array]) {
            foreach ($import in $imports) {
                $content = $content -replace [regex]::Escape("$import`r`n"), ""
                $content = $content -replace [regex]::Escape("$import`n"), ""
            }
        } else {
            $content = $content -replace [regex]::Escape("$imports`r`n"), ""
            $content = $content -replace [regex]::Escape("$imports`n"), ""
        }
        
        Set-Content -Path $fullPath -Value $content -NoNewline
        Write-Host "Processed: $file"
    }
}

Write-Host "Done!"
