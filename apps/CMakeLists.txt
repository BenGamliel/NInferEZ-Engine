# Modified by NInferEZ Engine in 2026: expose a stable machine-readable engine contract.
# The build id is stamped at BUILD time (see cmake/GenerateBuildId.cmake) into a generated header,
# so it reflects the tree actually being compiled rather than the last configure. Every product
# binary records it in its startup log ("build <id>"). The header is only rewritten when its
# content changes, so each main.cpp recompiles only when the id does.
set(NINFER_BUILD_ID_HEADER "${CMAKE_BINARY_DIR}/generated/ninfer_build_id.h")
add_custom_target(ninfer_build_id_stamp ALL
  COMMAND ${CMAKE_COMMAND}
          -DSRC_DIR=${CMAKE_SOURCE_DIR}
          -DOUT=${NINFER_BUILD_ID_HEADER}
          -P ${CMAKE_SOURCE_DIR}/cmake/GenerateBuildId.cmake
  BYPRODUCTS ${NINFER_BUILD_ID_HEADER}
  COMMENT "Stamping NINFER build id from git (build-time)"
  VERBATIM)

# A product binary depends on the stamp, and lists the header as a source so a changed id
# recompiles its main.cpp under every generator.
function(ninfer_stamp_build_id target)
  add_dependencies(${target} ninfer_build_id_stamp)
  target_sources(${target} PRIVATE ${NINFER_BUILD_ID_HEADER})
  target_include_directories(${target} PRIVATE ${CMAKE_BINARY_DIR}/generated)
endfunction()

add_executable(ninfer
  cli/main.cpp
  cli/options.cpp)
ninfer_internal_includes(ninfer)
target_link_libraries(ninfer PRIVATE
  ninfer_engine
  ninfer_product_logging
  ninfer_product_prompt_input)
ninfer_stamp_build_id(ninfer)
ninfer_stage_runtime_dlls(ninfer)

add_executable(ninfer-serve serve/main.cpp)
ninfer_internal_includes(ninfer-serve)
file(STRINGS "${CMAKE_SOURCE_DIR}/VERSION" NINFEREZ_ENGINE_VERSION LIMIT_COUNT 1)
string(STRIP "${NINFEREZ_ENGINE_VERSION}" NINFEREZ_ENGINE_VERSION)
target_compile_definitions(ninfer-serve PRIVATE
  NINFEREZ_ENGINE_VERSION="${NINFEREZ_ENGINE_VERSION}"
  NINFEREZ_ENGINE_CONTRACT=1
  NINFEREZ_CUDA_ARCH="${CMAKE_CUDA_ARCHITECTURES}")
target_link_libraries(ninfer-serve PRIVATE ninfer_serve ninfer_product_logging ninfer::json)
ninfer_stamp_build_id(ninfer-serve)
ninfer_stage_runtime_dlls(ninfer-serve)

add_executable(ninfer-inspect inspect/main.cpp)
ninfer_internal_includes(ninfer-inspect)
target_compile_definitions(ninfer-inspect PRIVATE
  NINFEREZ_ENGINE_VERSION="${NINFEREZ_ENGINE_VERSION}"
  NINFEREZ_ENGINE_CONTRACT=1
  NINFEREZ_CUDA_ARCH="${CMAKE_CUDA_ARCHITECTURES}")
target_link_libraries(ninfer-inspect PRIVATE ninfer_artifact ninfer::json)
ninfer_stamp_build_id(ninfer-inspect)

add_executable(ninfer-calibrate calibrate/main.cpp)
ninfer_internal_includes(ninfer-calibrate)
target_link_libraries(ninfer-calibrate PRIVATE ninfer_calibration ninfer_runtime_support)
ninfer_stage_runtime_dlls(ninfer-calibrate)

add_executable(ninfer-perplexity
  perplexity/main.cpp
  perplexity/corpus.cpp
  perplexity/evaluation.cpp)
ninfer_internal_includes(ninfer-perplexity)
target_link_libraries(ninfer-perplexity PRIVATE
  ninfer_engine ninfer_product_logging ninfer::json)
ninfer_stamp_build_id(ninfer-perplexity)
ninfer_stage_runtime_dlls(ninfer-perplexity)

if(WIN32 AND NINFER_DIRECTSTORAGE)
  foreach(app IN ITEMS ninfer ninfer-serve)
    add_custom_command(TARGET ${app} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${NINFER_DIRECTSTORAGE_DLLS}
              $<TARGET_FILE_DIR:${app}>)
  endforeach()
endif()
