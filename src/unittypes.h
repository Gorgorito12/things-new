// Extra abstract unit types. The game registers a fixed list of abstract unittype names
// (FUN_0051A5DC); a <UnitType> in protoy.xml that is not on it is dropped. Features that read a
// marker type from data request it here, and the name is registered after the stock list on
// every database load, so protoy.xml and techtrees can use it like any built-in type.
#pragma once

#include <cstdint>

namespace uhc {

// Registers `name` (copied) as an abstract unit type. On each database load `*id` receives its
// unittype ID (the existing one if the data already defines the name); it is -1 until then.
// Installs the registration hook on first use; false if the host bytes do not match.
bool RequestAbstractUnitType(const char* name, std::int32_t* id);

// Calls `callback(database)` on every database load, from the same hook: after the abstract types
// are registered and before the contents of the protos (their <ProtoAction> children among them)
// are read. Installs the hook on first use; false if the host bytes do not match.
bool OnDatabaseLoad(void (*callback)(char* database));

}  // namespace uhc
