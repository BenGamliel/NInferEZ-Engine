#include "ops/linear/common/route_table.h"

#include <cuda_runtime.h>

#include <array>
#include <atomic>
#include <cstdlib>
#include <optional>
#include <string_view>

namespace ninfer::ops::detail {
namespace {

constexpr int kMaxDevices = 64;

// -1: nothing forced; otherwise the forced table.
std::atomic<int>& forced_for_tests() {
    static std::atomic<int> forced{-1};
    return forced;
}

std::optional<LinearRouteTable> forced_table() {
    const char* value = std::getenv("NINFER_LINEAR_ROUTES");
    if (value == nullptr) return std::nullopt;
    const std::string_view name(value);
    if (name == "legacy") return LinearRouteTable::Legacy;
    if (name == "unified") return LinearRouteTable::Unified;
    return std::nullopt;
}

LinearRouteTable device_default(int device) {
    int major = 0;
    if (cudaDeviceGetAttribute(&major, cudaDevAttrComputeCapabilityMajor, device) != cudaSuccess) {
        cudaGetLastError();
        return LinearRouteTable::Legacy;
    }
    return major >= 12 ? LinearRouteTable::Unified : LinearRouteTable::Legacy;
}

} // namespace

LinearRouteTable linear_route_table() {
    if (const int value = forced_for_tests().load(std::memory_order_relaxed); value >= 0) {
        return static_cast<LinearRouteTable>(value);
    }
    static const std::optional<LinearRouteTable> forced = forced_table();
    if (forced) return *forced;
    int device = 0;
    if (cudaGetDevice(&device) != cudaSuccess) {
        cudaGetLastError();
        return LinearRouteTable::Legacy;
    }
    if (device < 0 || device >= kMaxDevices) return device_default(device);
    // 0: unknown; otherwise the table plus one. Racing first lookups store the same value.
    static std::array<std::atomic<std::uint8_t>, kMaxDevices> cached{};
    std::atomic<std::uint8_t>& slot = cached[static_cast<std::size_t>(device)];
    std::uint8_t value              = slot.load(std::memory_order_relaxed);
    if (value == 0) {
        value = static_cast<std::uint8_t>(static_cast<std::uint8_t>(device_default(device)) + 1);
        slot.store(value, std::memory_order_relaxed);
    }
    return static_cast<LinearRouteTable>(value - 1);
}

void force_linear_route_table(std::optional<LinearRouteTable> table) {
    forced_for_tests().store(table ? static_cast<int>(*table) : -1, std::memory_order_relaxed);
}

} // namespace ninfer::ops::detail
