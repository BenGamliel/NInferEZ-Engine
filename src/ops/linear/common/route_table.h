#pragma once

#include <cstdint>
#include <optional>

namespace ninfer::ops::detail {

// The route tables a pure Linear shape follows. The unified-template tables were measured on an
// RTX 5090; the legacy tables are this line's routes from before those templates, over the
// kernels they were tuned with. NINFER_LINEAR_ROUTES=legacy|unified overrides the device default.
enum class LinearRouteTable : std::uint8_t {
    Legacy,
    Unified,
};

[[nodiscard]] LinearRouteTable linear_route_table();

// Tests run each shape under both tables: a forced table wins over the environment and the device
// default until it is cleared with nullopt. Not for use while other threads launch Linear Ops.
void force_linear_route_table(std::optional<LinearRouteTable> table);

} // namespace ninfer::ops::detail
