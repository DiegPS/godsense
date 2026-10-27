# Shared inventory for the full local verification pipeline.
function Get-GodSenseGroupedWindowsTests {
    @(
        'integration_test/ui/connected_league_test.dart',
        'integration_test/ui/desktop_app_test.dart',
        'integration_test/ui/native_window_test.dart',
        'integration_test/ui/overlay_hud_test.dart',
        'integration_test/ui/scout_search_test.dart',
        'integration_test/ui/settings_controls_test.dart',
        'integration_test/ui/windows_artifact_download_test.dart'
    )
}

function Get-GodSenseInstalledRuntimeTests {
    @(
        'test/infrastructure/ai/ai_model_catalog_live_test.dart',
        'integration_test/ai_runtime_process_test.dart',
        'integration_test/kilo_streaming_test.dart',
        'integration_test/kilo_real_conversation_e2e_test.dart',
        'integration_test/installed_model_migration_test.dart',
        'integration_test/ui/real_ai_chat_test.dart',
        'test/infrastructure/speech/sherpa_speech_integration_test.dart',
        'test/infrastructure/speech/sherpa_tts_integration_test.dart'
    )
}
