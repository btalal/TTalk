# A standalone entry point: its CRT is static so no DLLs are needed beside it.
add_executable(ttalk_launcher WIN32 "main.cpp" "Launcher.rc")
apply_standard_settings(ttalk_launcher)
set_target_properties(ttalk_launcher PROPERTIES
  OUTPUT_NAME "TTalk"
  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
)
target_link_libraries(ttalk_launcher PRIVATE user32)
