// The game's Granny pose sampling, owned here for every key that needs it: the IAT slot 0xB847AC of
// granny2!GrannySampleModelAnimations (an import bound at load time, no delay load). Every pose the game builds
// goes through it: the four sample sites (0x40768B, the bone frame getter's path that attachments and tags read;
// 0x4DB727; 0xADCC34 and 0xADCE4F, the draw) each sample a model instance [visual+24h] into the shared local pose
// [[0xC67318]+8] and then build its world pose from it (GrannyBuildWorldPose). An observer sees the local pose
// between the two and may change bones in it: what it writes shows in the draw and in every bone a later read takes.
// One owner, so two keys never write the slot twice.
#pragma once

namespace uhc {

// After the stock sampling of `modelInstance`'s bones [first, first + count) into `localPose` (granny_local_pose*).
using GrannySampleObserver = void (*)(void* modelInstance, int first, int count, void* localPose);

// Adds an observer, in kFeatures order. The first one points the IAT slot at the wrapper. False (logged with `who`)
// if the slot does not point at granny2.dll's GrannySampleModelAnimations (another DLL changed it).
bool AddGrannySampleObserver(GrannySampleObserver observer, const char* who);

// granny2.dll's export `name` (e.g. "_GrannyGetLocalPoseTransform@8"), or nullptr (logged with `who`).
void* GrannyExport(const char* name, const char* who);

}  // namespace uhc
