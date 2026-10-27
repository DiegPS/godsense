# Shared inventory for the full local verification pipeline.
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
