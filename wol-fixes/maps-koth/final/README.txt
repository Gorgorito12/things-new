King of the Hill: overview, for review
======================================

113 maps got King of the Hill; 8 were skipped. The overview sheets 00-overview-*.jpg show every
added map's minimap (one 4-player test game): the magenta ring is the hill, the numbered squares are the Town Centers.
One picture per map is in ..\media\<map>.jpg; the per-map test results are in ..\koth-maps.csv and ..\README.md;
the changed scripts are in ..\RM4\.

Skipped (the map description says "King of the Hill: No"):
  dansil_Micronesia: every player starts on an island of their own
  DansilFalklands: players start on separate islands with no land between them
  DansilIbalong: players start on separate islands with no land between them
  everglades: players start on separate islands around the central one
  galapagos: players start on separate islands; the map's own King of the Hill line was left commented out and could not work: it uses a variable that does not exist (bigLoc) and its X for the Y
  WOLbalkans: the peninsulas and islands split the players: no spot is reachable on foot by both teams at a fair distance (tested: some players cannot walk to it, team distances up to 6 to 1)
  WOLbritishislands: players start on two islands (Ireland and Britain) with no land between them
  WOLFjord: the fjords split the land: no spot is fair to both teams and reachable on foot by all of them (tested); its King of the Hill include was commented out, and stays so
