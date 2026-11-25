if GetLocale() ~= "frFR" then
    return
end

local _, ns = ...

ns.Translation = {
    ["/mye minimap: hide this icon"] = "/mye minimap : cacher cette icône",
    ["Commands: /mye (show or hide), lock, scale 0.5-2, reset, minimap, demo."] =
        "Commandes : /mye (afficher ou cacher), lock, scale 0.5-2, reset, minimap, demo.",
    ["DPS"] = "DPS",
    ["Damage meter unavailable."] = "Compteur de dégâts indisponible.",
    ["Damage"] = "Dégâts",
    ["Demo dungeon"] = "Donjon de démo",
    ["Demo off."] = "Démo désactivée.",
    ["Demo on: /mye demo again to turn it off."] = "Démo activée : /mye demo à nouveau pour l'arrêter.",
    ["Drag: move this icon"] = "Glisser : déplacer cette icône",
    ["Left-click: show or hide the window"] = "Clic gauche : afficher ou cacher la fenêtre",
    ["Minimap icon hidden. Type /mye minimap to bring it back."] =
        "Icône de la minicarte cachée. Tapez /mye minimap pour la faire revenir.",
    ["No damage yet."] = "Pas encore de dégâts.",
    ["No flask"] = "Sans flacon",
    ["No food"] = "Sans nourriture",
    ["Right-click: lock or unlock the window"] = "Clic droit : verrouiller ou déverrouiller la fenêtre",
    ["Window locked."] = "Fenêtre verrouillée.",
    ["Window unlocked: drag it to move it."] = "Fenêtre déverrouillée : faites-la glisser pour la déplacer.",
}
