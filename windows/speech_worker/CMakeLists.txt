add_executable(godsense_speech_worker WIN32 main.cpp)
target_compile_features(godsense_speech_worker PRIVATE cxx_std_17)
target_compile_options(godsense_speech_worker PRIVATE /W4 /EHsc /utf-8)
target_compile_definitions(godsense_speech_worker PRIVATE NOMINMAX)
install(TARGETS godsense_speech_worker RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
install(FILES third_party/LICENSE.sherpa-onnx
  DESTINATION "${CMAKE_INSTALL_PREFIX}/data/licenses" COMPONENT Runtime)
