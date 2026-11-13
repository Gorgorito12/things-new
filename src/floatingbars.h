// The floating bars over the units (the HP bars), shared by every key that adds a bar of its own
// (overhealHitpointBars segment, inventoryBars): one jmp per site, whichever of those keys are on
// (hooks/floatingbars_hooks.asm).
//
// - 0x45FB6C, the bar chunk of the unit visual update right after it queued a unit's HP bar: the observers get the
//   unit and the bar's position, and may queue bars of their own there.
// - 0x45C4B9, the renderer FUN_0045C4AF before its vertex lock: when the queue would not fit in the dynamic vertex
//   buffer (stock then draws no bar that frame), every added bar is dropped, so they never cost a stock bar.
// - 0x45CB72, the end of the renderer's per-record loop: an added bar's six vertices, written by the stock loop like
//   a stock bar's, go to the writer of its kind.
//
// An added bar is a record of the stock queue with a negative player ID, which no player has (the renderer then
// colours it white): its kind is the ID without its low byte, which the key may use as it likes.
#pragma once

#include <cstdint>

namespace uhc {

struct FloatingBarRecord {  // a queued bar (1Ch bytes)
  float position[3];
  float scale;
  float fill;
  std::int32_t player;
  std::uint8_t colourByte;
  std::uint8_t padding[3];
};
static_assert(sizeof(FloatingBarRecord) == 0x1C);

struct FloatingBarVertex {  // the renderer's vertex (24h bytes)
  float position[3];
  float normal[3];
  std::uint32_t colour;
  float u;
  float v;
};
static_assert(sizeof(FloatingBarVertex) == 0x24);

// After a unit's HP bar was queued at position (world space). constructing: the bar is the build fraction of a
// foundation; altHeld: the game's own state of the Alt key (the modifier query 0x473E37(2) the chunk made, which
// shows every unit's HP bar while Alt is held).
using FloatingBarQueued = void (*)(const char* unit, const float* position, bool constructing, bool altHeld);

// The six vertices of one added bar (v0, v2, v3 on its left, v1, v4, v5 on its right, as the stock loop wrote them
// for record.fill), and the camera ([+1Ch] its up vector, [+28h] its right vector).
using FloatingBarVertices = void (*)(const FloatingBarRecord& record, FloatingBarVertex* vertices, const char* camera);

// Writes the queue hook the first time (after checking the sites' stock bytes) and adds observer.
bool AddFloatingBarQueued(FloatingBarQueued observer, const char* feature);

// Writes the two renderer hooks the first time and adds a kind: player IDs whose high three bytes are those of kind
// (negative, as 0x804F5600).
bool AddFloatingBarKind(std::uint32_t kind, FloatingBarVertices writer, const char* feature);

// Queues one bar of scale 1 at position, as the stock queue 0x45FB71 does for a unit.
void QueueFloatingBar(const float* position, float fill, std::uint32_t player);

}  // namespace uhc
