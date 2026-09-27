#pragma once

#include <cstdint>
#include <optional>

namespace ninfer::ops::detail {

// The route tables a pure Linear shape follows. The unified-template tables were measured on an
// RTX 5090; the legacy tables are this line's routes from before those templates, over the
// kernels they were tuned with.
enum class LinearRouteTable : std::uint8_t {
    Legacy,
    Unified,
};

enum class LinearRouteFamily : std::uint8_t {
    Q4,
    Q5,
    Q6,
    Q8,
};

// The table for one call: by default the unified table only inside the width bands where it was
// measured faster on this device's class, and the legacy table everywhere else;
// NINFER_LINEAR_ROUTES=legacy|unified takes one table for every width.
[[nodiscard]] LinearRouteTable linear_route_table(LinearRouteFamily family, std::int32_t t);

// Tests run each shape under both tables: a forced table wins over the environment and the device
// default until it is cleared with nullopt. Not for use while other threads launch Linear Ops.
void force_linear_route_table(std::optional<LinearRouteTable> table);

} // namespace ninfer::ops::detail
