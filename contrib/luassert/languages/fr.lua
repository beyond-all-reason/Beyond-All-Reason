local s = require('say')

s:set_namespace('fr')

s:set("assertion.called.positive", "Prévu pour être appelé %s fois(s), mais a été appelé %s fois(s).")
s:set("assertion.called.negative", "Prévu de ne pas être appelé exactement %s fois(s), mais ceci a été le cas.")

s:set("assertion.called_at_least.positive", "Prévu pour être appelé au moins %s fois(s), mais a été appelé %s fois(s).")
s:set("assertion.called_at_most.positive", "Prévu pour être appelé au plus %s fois(s), mais a été appelé %s fois(s).")

s:set("assertion.called_more_than.positive", "Devrait être appelé plus de %s fois(s), mais a été appelé %s fois(s).")
s:set("assertion.called_less_than.positive", "Devrait être appelé moins de %s fois(s), mais a été appelé %s fois(s).")

s:set("assertion.called_with.positive", "La fonction n'a pas été appelée avec les arguments.")
s:set("assertion.called_with.negative", "La fonction a été appelée avec les arguments.")

s:set("assertion.equals.positive", "Les objets attendus doivent être égaux. \n Argument passé en: \n %s \n Attendu: \n %s.")
s:set("assertion.equals.negative", "Les objets attendus ne doivent pas être égaux. \n Argument passé en: \n %s \n Non attendu: \n %s.")

s:set("assertion.error.positive", "Une erreur différente est attendue. \n Prise: \n %s \n Attendue: \n %s.")
s:set("assertion.error.negative", "Aucune erreur attendue, mais prise: \n %s.")

s:set("assertion.falsy.positive", "Assertion supposée etre fausse mais de valeur: \n %s")
s:set("assertion.falsy.negative", "Assertion supposée etre vraie mais de valeur: \n %s")

-- errors
s:set("assertion.internal.argtolittle", "La fonction '%s' requiert un minimum de %s arguments, obtenu: %s.")
s:set("assertion.internal.badargtype", "Mauvais argument #%s pour '%s' (%s attendu, obtenu %s).")
-- errors

s:set("assertion.matches.positive", "Chaînes attendues pour correspondre. \n Argument passé en: \n %s \n Attendu: \n %s.")
s:set("assertion.matches.negative", "Les chaînes attendues ne doivent pas correspondre. \n Argument passé en: \n %s \n Non attendu: \n %s.")

s:set("assertion.near.positive", "Les valeurs attendues sont proches. \n Argument passé en: \n %s \n Attendu: \n %s +/- %s.")
s:set("assertion.near.negative", "Les valeurs attendues ne doivent pas être proches. \n Argument passé en: \n %s \n Non attendu: \n %s +/- %s.")

s:set("assertion.returned_arguments.positive", "Attendu pour être appelé avec le(s) argument(s) %s, mais a été appelé avec %s.")
s:set("assertion.returned_arguments.negative", "Attendu pour ne pas être appelé avec le(s) argument(s) %s, mais a été appelé avec %s.")

s:set("assertion.returned_with.positive", "La fonction n'a pas été retournée avec les arguments.")
s:set("assertion.returned_with.negative", "La fonction a été retournée avec les arguments.")

s:set("assertion.same.positive", "Les objets attendus sont les mêmes. \n Argument passé en: \n %s \n Attendu: \n %s.")
s:set("assertion.same.negative", "Les objets attendus ne doivent pas être les mêmes. \n Argument passé en: \n %s \n Non attendu: \n %s.")

s:set("assertion.truthy.positive", "Assertion supposee etre vraie mais de valeur: \n %s")
s:set("assertion.truthy.negative", "Assertion supposee etre fausse mais de valeur: \n %s")

s:set("assertion.unique.positive", "Objet attendu pour être unique: \n %s.")
s:set("assertion.unique.negative", "Objet attendu pour ne pas être unique: \n %s.")
