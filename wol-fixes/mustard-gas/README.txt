MUSTARD GAS EMPTIES MILLS AND PLANTATIONS (request #75)
======================================================

What breaks
-----------
After the zeppelin's mustard gas (gwMustardGas) has covered an enemy Mill, plantation, rice paddy or similar
building, villagers can no longer gather there. They walk to it and stand idle beside it; its tooltip says
"Current Gatherers: 0". It lasts for the rest of the game (still broken 6 minutes after the gas was gone).
Villagers that were working there when the gas came are killed by it, as intended. Training, and buildings
the gas did not touch, are not affected.

Why
---
The gas clouds attack with a tactics action of type TruckAttack (GW_Mustardgas.tactics), the type the stock
monster truck uses. That action, in the game's own code, hits every enemy unit within its maxrange about five
times a second, and before each hit it sets the whole resource inventory of that unit to 0. For a trampled
animal that is the point. For a Mill (999 food) or a plantation (999 gold) it leaves the building with 0, and
<UnlimitedSupply> never refills it, so there is nothing left to gather. Read from the game's memory: a Mill
under the gas went from 999 food to 0.

It is not the gas's data: a copy of the gas without Resource / AnimalPrey / NatureClass, owned by Gaia, unable
to move, without area damage, without the projectile, collideable or with a smaller range still emptied the
Mill. Only copies whose attack did nothing at all (no <persistent>, maxrange 0, or another action type, which
also took away all the damage) spared it. 25 variants were tried. Your other TruckAttack units do the same:
POWERtornado, POWERIncendio and the stock MonsterTruckA emptied Mills in the same test; the plague,
gwExplosion, gwBulldozer and T34 use the same action and were not tried.

So there is no data fix that keeps the gas's damage.

The fix
-------
A new line for engine-ext\engine-ext.cfg (our dinput8.dll beside your own uhc.dll, the usual WoL setup), or for
Startup\wol.cfg only if our UHC.dll is used in place of yours:

  truckAttackResourceFix

A TruckAttack no longer resets the resources of a building it hits. The damage is exactly the same (measured:
a 60000 HP Target under five gas clouds lost 352 HP per second with the line and 357 without, within the
randomness of the gas's wandering), and units (a hunted animal, a villager) are still emptied as before.
Add "log" to see the first hit on each building in the log:

  truckAttackResourceFix log
  -> truckAttackResourceFix: unit 0 (Mill, player 1) hit by unit 19 (gwMustardGas, player 2): its resources kept

Every player of a game needs the same line. A building that was emptied before the line was added stays empty.

Videos: docs/media/truckAttackResourceFix-wol.mp4 (with the line: four settlers gather at the plantation after
the gas) and truckAttackResourceFix-wol-control.mp4 (without it: they stand idle beside it).

Undo
----
Remove the line. No data file is changed.
