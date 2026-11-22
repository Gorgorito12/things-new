// The placement ghost's update, shared by the keys that act on it (annexFacing, displayedRange). FUN_0096E062 moves
// the ghost of the building being placed to the pointer and then tests the placement at 0x96E531; its line 0x96E4E7
// (mov eax,[0C66234h], the first of that test's arguments) is replaced once by a jump, whichever keys are on, and the
// hook runs every observer there, in the order the keys add them (their kFeatures order).
#pragma once

namespace uhc {

// Called on every update of the ghost (each frame while a building is being placed, the game paused too), with
// ESI of the update: the ghost's visual, [[0xC67300]+200h] (its axes from +4: position, forward +10h, up +1Ch,
// right +28h; +7Dh marks them changed). The proto being placed is [[0xC67300]+1FCh]. Local view only: the ghost is
// this machine's, and the build command carries its own transform.
using GhostObserver = void(__stdcall*)(char* visual);

// Writes the jump the first time (after checking the site's stock bytes) and adds the observer.
bool AddGhostObserver(GhostObserver observer);

}  // namespace uhc
