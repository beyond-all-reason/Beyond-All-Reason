local s = require('say')

s:set_namespace('is')

s:set("assertion.same.positive", "Átti von á að vera eins.\nSett inn:\n%s\nBjóst við:\n%s")
s:set("assertion.same.negative", "Átti von á að ekki vera eins.\nSett inn:\n%s\nBjóst ekki við:\n%s")

s:set("assertion.equals.positive", "Átti von á að vera jöfn.\nSett inn:\n%s\nBjóst við:\n%s")
s:set("assertion.equals.negative", "Átti von á að ekki vera jöfn.\nSett inn:\n%s\nBjóst ekki við:\n%s")

s:set("assertion.near.positive", "Átti von á að vera svipuð.\nSett inn:\n%s\nBjóst við:\n%s +/- %s")
s:set("assertion.near.negative", "Átti von á að ekki vera svipuð.\nSett inn:\n%s\nBjóst ekki við:\n%s +/- %s")

s:set("assertion.matches.positive", "Átti von á að strengir væru eins.\nSett inn:\n%s\nBjóst við:\n%s")
s:set("assertion.matches.negative", "Átti von á að strengir væru ekki eins.\nSett inn:\n%s\nBjóst ekki við:\n%s")

s:set("assertion.unique.positive", "Átti von á að vera einstök:\n%s")
s:set("assertion.unique.negative", "Átti von á að ekki vera einstök:\n%s")

s:set("assertion.error.positive", "Átti von á annarri villu.\nFékk:\n%s\nBjóst við:\n%s")
s:set("assertion.error.negative", "Átti ekki von á neinni villu en fékk:\n%s")

s:set("assertion.truthy.positive", "Átti von á sönnu gildi en gildi var:\n%s")
s:set("assertion.truthy.negative", "Átti ekki von á sönnu gildi en gildi var:\n%s")

s:set("assertion.falsy.positive", "Átti von á ósönnu gildi en gildi var:\n%s")
s:set("assertion.falsy.negative", "Átti ekki von á ósönnu gildi en gildi var:\n%s")

s:set("assertion.called.positive", "Átti von á að vera kallað %s sinnum en var kallað %s sinnum")
s:set("assertion.called.negative", "Átti von á að ekki vera kallað %s sinnum en var")

s:set("assertion.called_at_least.positive",  "Átti von á að vera kallað að minnsta kosti %s sinnum an var kallað %s sinnum")
s:set("assertion.called_at_most.positive",   "Átti von á að vera kallað að mesta lagi %s sinnum an var kallað %s sinnum")
s:set("assertion.called_more_than.positive", "Átti von á að vera kallað oftar en %s sinnum an var kallað %s sinnum")
s:set("assertion.called_less_than.positive", "Átti von á að vera kallað færra en %s sinnum an var kallað %s sinnum")

s:set("assertion.called_with.positive", "Undirforrit var aldrei kallað með passandi færibreytum.\nKallað með (síðasta):\n%s\nBjóst við:\n%s")
s:set("assertion.called_with.negative", "Undirforrit var kallað með passandi færibreytum.\nKallað með (síðasta):\n%s\nBjóst ekki við:\n%s")

s:set("assertion.returned_with.positive", "Undirforrit skilaði aldrei samsvarandi breytu.\nSkilað (síðasta):\n%s\nBjóst við:\n%s")
s:set("assertion.returned_with.negative", "Undirforrit skilaði samsvarandi breytu.\nSkilað (síðasta):\n%s\nBjóst ekki við:\n%s")

s:set("assertion.returned_arguments.positive", "Átti von á að vera kallað með færibreytum %s en var kallað með %s")
s:set("assertion.returned_arguments.negative", "Átti von á að ekki vera kallað með færibreytum %s en var kallað með %s")

-- errors
s:set("assertion.internal.argtolittle", "undirforritið „%s“ krefst lágmarks %s færibreyti en fékk: %s")
s:set("assertion.internal.badargtype", "slæmt færibreyti #%s til „%s“ (átti von á %s en fékk %s)")
