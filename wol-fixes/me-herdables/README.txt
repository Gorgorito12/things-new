MIDDLE EAST HERDABLES FOR WARS OF LIBERTY (request #79)
=====================================================

(Spanish below / Español más abajo)

What it does
------------
The Middle East nomads (Nomad, NomadKarakalpak, NomadTurkman, NomadKyrgyz, Bedouin, BedouinFree) become moving
livestock pens:
  - herdables (sheep, goats, camels, Karakul sheep...) gather from a nomad as they do from a Livestock Pen: they
    fatten, and they do it from about 3 m away;
  - when the nomad walks, the herdables gathering from it follow it and keep fattening;
  - idle herdables within 10 m of a nomad are drawn to it on their own (the game's own "magnet": the unit type
    AbstractTypeHerdableMagnet, which the Ranch and the Asian livestock pen already have);
  - a fattened herdable walks a few metres away from the nomad, as it does from a pen, and stays there.

All of that is the game's own behaviour once the nomads have the right data; no new code was needed for it. What the
data needs (found by testing, 2026-11-21):
  - AbstractTypeHerdableMagnet on the nomad: it draws idle herdables (10 m) and sends fattened ones away;
  - the unit type Resource, the flag UnlimitedSupply, <GathererLimit>10 and <InitialResource resourcetype="Food">999 on
    the nomad, as a Livestock Pen has them. Without them the game refuses the gather order: a herdable ordered to gather
    a nomad that had only the magnet type and a <rate> did nothing. UnlimitedSupply keeps the nomad's 999 food from
    going down (it stayed at 999 with eight herdables on it);
  - a <rate type="Nomad"> (one per nomad) in the Gather action of herd.tactics and herdcoin.tactics, and a
    <typedmaxrange type="Nomad">3</typedmaxrange>: the distance. The game respects it, and pens keep the action's 0.5 m.

One fix in the DLL, the key `herdWalkAwayFix`: when a fattened herdable walks away from its pen or nomad, the game
does not move the herdable's "leash" point (the place the game walks an idle unit back to). A herdable the magnet drew
in keeps the leash point it had before, where it was born or last ordered. With a pen that is a few metres away; with a
nomad that has walked on, it is across the map: in a test with the stock 0.5 m range, two fattened sheep of three
walked 33 m back to where the herd had started. The key puts the leash point where the herdable walked to.
With this pack's 3 m range, in two tests the fattened sheep stayed near the nomad even without the key; keep the key
on anyway.

The nomads' CattleFatteningAura (x4 AutoGatherRate on herdables within 12 m) is left as it is: with it, a sheep fattened
from 100 to 300 food in about 2.5 minutes. Tell us if it should go (see the question below).

Installing
----------
  python apply_fix.py "<WoL folder>"             applies it, with a backup in <WoL folder>\me-herdables-backup
  python apply_fix.py "<WoL folder>" --check     says what is applied
  python apply_fix.py "<WoL folder>" --restore   puts everything back

It adds the line `herdWalkAwayFix` to Startup\wol.cfg when the file has none. The key comes with our UHC.dll, or with
our dinput8.dll beside WoL's own DLL (in that case the line goes in engine-ext\engine-ext.cfg instead).

Files it changes:
  data\protoy.xml                     the six nomads: two unit types, a flag, GathererLimit, InitialResource Food
  data\tactics\herd.tactics           the Gather action: a rate and a typed range of 3 m per nomad
  data\tactics\herdcoin.tactics       the same
  Startup\wol.cfg                     the line herdWalkAwayFix

To change the distance, change the 3 in the <typedmaxrange> lines (or DISTANCE at the top of apply_fix.py before
applying). To do the same for another unit, give it the same four things in protoy.xml and add its proto to the herd
tactics.

Tested (2026-11-21, single player, a copy of WoL with our UHC.dll)
-----------------------------------------------------------------
  - Scenario: a Nomad, three sheep and five camels. The camels ordered to the Nomad and the sheep within 10 m (drawn on
    their own) gathered from it; the Nomad walked 32 m and the herd followed, gathering; the sheep reached 300 food and
    walked away 8 to 10 m; the camels kept fattening (390+).
  - Skirmish as Persians (they start with a Nomad) against a German AI: sheep trained at the Nomad gathered from it at
    once; the AI played (12 to 18 units in 2.5 minutes, a Manor built), no XS error.
  - herdWalkAwayFix: with the key the fattened sheep stayed by the nomad; without it, in the 0.5 m setup, two walked back
    33 m (videos herdWalkAwayFix-wol.mp4 and herdWalkAwayFix-wol-control.mp4).
Not tested: the AI's own use of the nomads' herds over a whole game, and multiplayer.

Questions for the WoL team
--------------------------
  1. Should the nomads keep their CattleFatteningAura now that herdables gather from them? Kept for now. With both, a
     herdable fattens from the gather and from the aura.
  2. Is 3 m the distance you want, the same for all six nomads?
  3. Should fattened herdables follow the nomad when it walks on (they stay where they walked away to now, as at a pen)?


HERDABLES DE ORIENTE MEDIO PARA WARS OF LIBERTY (pedido #79)
==========================================================

Qué hace
--------
Los nómadas de Oriente Medio (Nomad, NomadKarakalpak, NomadTurkman, NomadKyrgyz, Bedouin, BedouinFree) pasan a ser
corrales que se mueven:
  - los animales de rebaño (ovejas, cabras, camellos, ovejas karakul...) recolectan del nómada como de un corral:
    engordan, y lo hacen a unos 3 m;
  - cuando el nómada camina, los animales que recolectan de él lo siguen y siguen engordando;
  - los animales inactivos a menos de 10 m de un nómada van hacia él solos (el "imán" del propio juego: el tipo
    AbstractTypeHerdableMagnet, que ya tienen el Ranch y el corral asiático);
  - un animal engordado se aparta unos metros del nómada, como de un corral, y se queda ahí.

Todo eso lo hace el propio juego cuando los nómadas tienen los datos adecuados; no hizo falta código nuevo para ello.
Lo que necesitan los datos (comprobado en pruebas, 2026-11-21):
  - AbstractTypeHerdableMagnet en el nómada: atrae a los animales inactivos (10 m) y aparta a los engordados;
  - el tipo de unidad Resource, el flag UnlimitedSupply, <GathererLimit>10 y <InitialResource resourcetype="Food">999 en
    el nómada, como los tiene un corral. Sin ellos el juego rechaza la orden de recolectar: un animal mandado a recolectar
    de un nómada que solo tenía el tipo imán y un <rate> no hizo nada. UnlimitedSupply evita que baje la comida del nómada
    (se quedó en 999 con ocho animales recolectando);
  - un <rate type="Nomad"> (uno por nómada) en la acción Gather de herd.tactics y herdcoin.tactics, y un
    <typedmaxrange type="Nomad">3</typedmaxrange>: la distancia. El juego la respeta, y los corrales siguen con los 0,5 m
    de la acción.

Una corrección en el DLL, la clave `herdWalkAwayFix`: cuando un animal engordado se aparta de su corral o nómada, el
juego no mueve su punto de "correa" (el sitio al que el juego devuelve a una unidad inactiva). Un animal atraído por el
imán conserva el punto que tenía antes, donde nació o recibió su última orden. Con un corral eso queda a pocos metros;
con un nómada que ya se fue, queda al otro lado del mapa: en una prueba con el alcance de 0,5 m de serie, dos de tres
ovejas engordadas volvieron 33 m al sitio donde empezó el rebaño. La clave pone ese punto donde el animal se apartó.
Con los 3 m de este paquete, en dos pruebas las ovejas engordadas se quedaron junto al nómada incluso sin la clave;
dejadla activada de todos modos.

El aura CattleFatteningAura de los nómadas (x4 AutoGatherRate a los animales a 12 m) se queda como está: con ella, una
oveja pasó de 100 a 300 de comida en unos 2,5 minutos. Decidnos si debe quitarse (ver la pregunta abajo).

Instalación
-----------
  python apply_fix.py "<carpeta de WoL>"             lo aplica, con copia en <carpeta de WoL>\me-herdables-backup
  python apply_fix.py "<carpeta de WoL>" --check     dice qué está aplicado
  python apply_fix.py "<carpeta de WoL>" --restore   lo deja todo como estaba

Añade la línea `herdWalkAwayFix` a Startup\wol.cfg si no la tiene. La clave viene con nuestro UHC.dll, o con nuestro
dinput8.dll junto al DLL de WoL (en ese caso la línea va en engine-ext\engine-ext.cfg).

Archivos que cambia:
  data\protoy.xml                     los seis nómadas: dos tipos, un flag, GathererLimit, InitialResource Food
  data\tactics\herd.tactics           la acción Gather: un rate y un alcance por tipo de 3 m por nómada
  data\tactics\herdcoin.tactics       lo mismo
  Startup\wol.cfg                     la línea herdWalkAwayFix

Para cambiar la distancia, cambiad el 3 de las líneas <typedmaxrange> (o DISTANCE al principio de apply_fix.py antes de
aplicarlo). Para hacer lo mismo con otra unidad, dadle esas cuatro cosas en protoy.xml y añadid su proto a las tácticas
de rebaño.

Probado (2026-11-21, un jugador, una copia de WoL con nuestro UHC.dll)
----------------------------------------------------------------------
  - Escenario: un Nomad, tres ovejas y cinco camellos. Los camellos mandados al Nomad y las ovejas a menos de 10 m
    (atraídas solas) recolectaron de él; el Nomad caminó 32 m y el rebaño lo siguió recolectando; las ovejas llegaron a
    300 de comida y se apartaron 8 a 10 m; los camellos siguieron engordando (más de 390).
  - Escaramuza con los persas (empiezan con un Nomad) contra una IA alemana: las ovejas entrenadas en el Nomad
    recolectaron de él enseguida; la IA jugó (de 12 a 18 unidades en 2,5 minutos, construyó una Manor), sin error de XS.
  - herdWalkAwayFix: con la clave las ovejas engordadas se quedaron junto al nómada; sin ella, con 0,5 m, dos volvieron
    33 m (vídeos herdWalkAwayFix-wol.mp4 y herdWalkAwayFix-wol-control.mp4).
Sin probar: el uso que hace la IA de los rebaños de los nómadas en una partida entera, y el multijugador.
