<?php
// Written by factory/prepare.py from apps/<app>/alpha.json. This default is a small demo.
return json_decode(<<<'JSON'
{"app":{"title":"Alpha Demo","slug":"demo","role":"single","rtl":true},
 "theme":{"seed":"#6E4BFF","accent":"#2DD4BF","mode":"dark","style":"glass","radius":18},
 "backend":{"type":"none","auth":"none"},
 "tables":[{"name":"tasks","label":"المهام","icon":"checklist","owner":"customer","notify":{"onInsert":"admin"},
   "columns":[{"name":"title","label":"المهمة","type":"text","required":true},
              {"name":"priority","label":"الأولوية","type":"choice","options":["عالية","متوسطة","منخفضة"],"default":"متوسطة"},
              {"name":"done","label":"تمت","type":"bool","default":"false"}]}]}
JSON, true, 512, JSON_THROW_ON_ERROR);
