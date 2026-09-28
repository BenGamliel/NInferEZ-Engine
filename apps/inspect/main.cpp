// Copyright 2026 NInferEZ Engine contributors.
// SPDX-License-Identifier: Apache-2.0

#include "artifact/reader.h"
#include "artifact/schema.h"
#include "ninfer_build_id.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

using Json = nlohmann::ordered_json;

[[noreturn]] void usage(const char* program, int code) {
    std::fprintf(code == 0 ? stdout : stderr,
                 "usage: %s --model PATH --json [--estimate-memory]\n"
                 "       %s --help\n"
                 "\n"
                 "Validates a NInfer v3 artifact directory without loading weights or using a GPU.\n"
                 "--estimate-memory reports exact encoded sizes and explicitly marks runtime VRAM\n"
                 "as unavailable until a device- and profile-aware runtime probe is performed.\n",
                 program, program);
    std::exit(code);
}

std::string artifact_id_hex(const ninfer::artifact::ArtifactId& id) {
    std::ostringstream output;
    output << std::hex << std::setfill('0');
    for (const std::byte value : id) {
        output << std::setw(2) << std::to_integer<unsigned>(value);
    }
    return output.str();
}

Json inspect(const std::filesystem::path& path, bool estimate_memory) {
    ninfer::artifact::Reader reader(path);
    const ninfer::artifact::Directory& directory = reader.directory();

    std::uint64_t tensor_bytes   = 0;
    std::uint64_t resource_bytes = 0;
    std::size_t tensor_count     = 0;
    std::size_t resource_count   = 0;
    std::set<std::string> formats;
    for (std::size_t index = 0; index < directory.objects.size(); ++index) {
        const ninfer::artifact::ObjectHandle handle{index};
        reader.validate_object(handle);
        const auto& object = directory.objects[index];
        if (const auto* tensor = std::get_if<ninfer::artifact::TensorObject>(&object)) {
            ++tensor_count;
            tensor_bytes += tensor->bytes;
            formats.insert(tensor->format);
        } else {
            ++resource_count;
            resource_bytes += std::get<ninfer::artifact::ResourceObject>(object).bytes;
        }
    }

    Json components = Json::array();
    for (const auto& [name, component] : directory.components) {
        Json record = {{"name", name},
                       {"config", component.config},
                       {"resourceCount", component.resources.size()},
                       {"hasProposal", component.proposal.has_value()}};
        if (component.target) { record["target"] = *component.target; }
        components.push_back(std::move(record));
    }

    const auto has_component = [&](std::string_view name) {
        return directory.components.contains(std::string(name));
    };
    const bool uses_nvfp4 = std::any_of(formats.begin(), formats.end(), [](const std::string& value) {
        return value.find("nvfp4") != std::string::npos || value.find("NVFP4") != std::string::npos;
    });
#ifdef NINFER_SM120_NVFP4
    constexpr bool native_nvfp4 = true;
#else
    constexpr bool native_nvfp4 = false;
#endif

    Json result = {{"schemaVersion", 1},
                   {"contractVersion", NINFEREZ_ENGINE_CONTRACT},
                   {"engineVersion", NINFEREZ_ENGINE_VERSION},
                   {"buildId", NINFER_BUILD_ID},
                   {"cudaArchitecture", std::string("sm") + NINFEREZ_CUDA_ARCH},
                   {"path", std::filesystem::absolute(path).string()},
                   {"valid", true},
                   {"containerVersion", 3},
                   {"artifactId", artifact_id_hex(reader.artifact_id())},
                   {"fileBytes", reader.file_bytes()},
                   {"payloadBytes", directory.payload_bytes},
                   {"metadata", directory.metadata},
                   {"provenance", directory.provenance},
                   {"components", std::move(components)},
                   {"tensorCount", tensor_count},
                   {"resourceCount", resource_count},
                   {"tensorBytes", tensor_bytes},
                   {"resourceBytes", resource_bytes},
                   {"weightFormats", Json::array()},
                   {"modelFeatures",
                    {{"vision", has_component("vision")},
                     {"mtp", has_component("mtp")},
                     {"dflash", has_component("dflash")},
                     {"dflash2", has_component("dflash2")}}},
                   {"compatibility",
                    {{"usesNvfp4Weights", uses_nvfp4},
                     {"nativeNvfp4Weights", native_nvfp4},
                     {"compatibleWithBuild", !uses_nvfp4 || native_nvfp4}}}};
    for (const auto& format : formats) { result["weightFormats"].push_back(format); }
    if (uses_nvfp4 && !native_nvfp4) {
        result["compatibility"]["reason"] =
            "This artifact uses NVFP4 weights and needs an sm120a build for complete model execution.";
    }
    if (estimate_memory) {
        result["memoryEstimate"] =
            {{"encodedTensorBytes", tensor_bytes},
             {"encodedResourceBytes", resource_bytes},
             {"runtimeVramAvailable", false},
             {"reason",
              "Runtime VRAM depends on GPU, context, KV format, speculation, concurrency and model-specific workspaces; use a runtime preflight rather than treating file size as VRAM."}};
    }
    return result;
}

} // namespace

int main(int argc, char** argv) {
    std::filesystem::path model;
    bool json            = false;
    bool estimate_memory = false;
    for (int index = 1; index < argc; ++index) {
        const std::string_view argument(argv[index]);
        if (argument == "--model") {
            if (++index >= argc) { usage(argv[0], 2); }
            model = argv[index];
        } else if (argument == "--json") {
            json = true;
        } else if (argument == "--estimate-memory") {
            estimate_memory = true;
        } else if (argument == "--help" || argument == "-h") {
            usage(argv[0], 0);
        } else {
            usage(argv[0], 2);
        }
    }
    if (model.empty() || !json) { usage(argv[0], 2); }

    try {
        std::cout << inspect(model, estimate_memory).dump(2) << '\n';
        return 0;
    } catch (const std::exception& error) {
        Json failure = {{"schemaVersion", 1},
                        {"contractVersion", NINFEREZ_ENGINE_CONTRACT},
                        {"valid", false},
                        {"error", {{"code", "artifact_invalid"}, {"message", error.what()}}}};
        std::cout << failure.dump(2) << '\n';
        return 1;
    }
}
