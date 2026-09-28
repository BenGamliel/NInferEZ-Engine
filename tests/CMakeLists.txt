# Modified by NInferEZ Engine in 2026 to register the host-only engine contract smoke test.
find_package(Python3 REQUIRED COMPONENTS Interpreter)

include(cmake/NinferTests.cmake)
include(cmake/CoreTests.cmake)
include(artifact/tests.cmake)
include(cmake/RuntimeTests.cmake)
include(cmake/ProductTests.cmake)
include(cmake/BenchSupportTests.cmake)
include(models/qwen3_5/tests.cmake)
include(ops/tests.cmake)

ninfer_finalize_bundle(ninfer_tests)

# Every test executable shares one per-config runtime directory; stage the FFmpeg/curl DLL closure
# there once so they resolve their imports (the Windows loader only searches the executable's own
# directory, the system directories and PATH).
ninfer_stage_test_runtime_dlls(ninfer_tests)

if(TARGET ninfer-serve AND TARGET ninfer-inspect)
  add_test(NAME ninferez_engine_contract_test
    COMMAND ${Python3_EXECUTABLE} -B
            "${PROJECT_SOURCE_DIR}/tests/test_ninferez_engine_contract.py"
            "$<TARGET_FILE:ninfer-serve>" "$<TARGET_FILE:ninfer-inspect>")
endif()
