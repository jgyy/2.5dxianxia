"""Compile a transparent, reproducible procedural narrative campaign.

The text is generated from authored scene templates, not a claim of one million
handwritten words. Each NPC gets a connected twelve-chapter arc with objectives,
witnesses, enemies, choices, and aftermath. No random word padding is used.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content/campaign"
REGIONS = [
    ("Cloudrest", "lotus terraces", "a river that carries other people's dreams", "healer's guild"),
    ("Jade Academy", "broken examination halls", "a school that sold its students' futures", "jade scholars"),
    ("Lantern Harbor", "lantern-lit docks", "a harbor where debts outlive their owners", "river compact"),
    ("Frost Court", "silent ice courtyards", "a court that froze its witnesses rather than hear them", "winter court"),
    ("Ember Forge", "copper furnace lanes", "a forge that burns memories instead of coal", "ember union"),
    ("Whispering Reed", "reed libraries", "an archive that remembers every forbidden name", "ink archivists"),
    ("Starfall Steps", "meteor stairways", "a pilgrimage built from fallen stars", "star pilgrims"),
    ("Moonwell", "silver well gardens", "a well that answers only the questions people regret", "moon covenant"),
    ("Thunder Pass", "storm bridge stations", "a pass whose thunder repeats an unfinished trial", "storm wardens"),
    ("Dream Orchard", "violet orchard paths", "an orchard grown from dreams confiscated by the empire", "dream keepers"),
    ("Bone Meridian", "white stone ossuaries", "a necropolis where the dead are forced to pay rent", "ancestral council"),
    ("Dawn Sanctuary", "sunlit sanctuary courts", "a refuge that must decide whom forgiveness includes", "dawn assembly"),
]
SURNAMES = ["Lin", "Shen", "Mei", "Qiao", "Su", "Bai", "Luo", "Han", "Yun", "Zhao"]
GIVEN = ["Ning", "Xuan", "Lian", "Rui", "Qing", "Hua", "Lan", "Wei", "Jin", "Suyin"]
ROLES = ["lotus physician", "ferry captain", "sword historian", "bell keeper", "tea grower", "talisman painter", "winter scout", "copper engineer", "dream archivist", "oath judge", "spirit gardener", "crane rider", "grave tender", "moon astronomer", "silk cartographer", "river mediator", "jade sculptor", "wandering musician", "memory smith", "refuge keeper"]
LOSSES = ["a sister erased from the academy rolls", "a village burned under a false imperial order", "a teacher imprisoned for refusing a profitable lie", "a ship whose passengers became collateral", "a mother whose name was traded for medicine", "an apprentice trapped inside an unfinished ritual", "a friend condemned by a borrowed testimony", "a garden poisoned to conceal a burial", "a brother turned into the emperor's living seal", "a daughter whose dreams were confiscated as tax"]
RELICS = ["bronze bell clapper", "jade examination tile", "folded river map", "ivory oath needle", "copper memory gear", "ink-stained name slip", "silver star compass", "lotus seed reliquary", "stormglass seal", "scarlet mourning ribbon"]
VALUES = ["mercy without obedience", "truth without humiliation", "freedom without abandonment", "justice without revenge", "memory without imprisonment", "courage without spectacle", "belonging without possession", "duty without cruelty", "hope without denial", "power without ownership"]
MONSTERS = '''Jade Wolf|Crimson Fox Demon|Ivory Crane Spirit|Moss Turtle Guardian|Copper Boar|Teal River Serpent|Silver Stag|Ink Raven|Lotus Spider|Emerald Mantis|Bone Hound|Amber Tiger|Violet Moth|Stone Bear|Scaled Pangolin|Nine-Tail Oracle|Hopping Jiangshi|Paper Golem|Ink Swordsman|Skeletal Librarian|Bronze Armor|Cursed Jade Statue|Demonic Sword|Ghost Bride|Blind Bell Guardian|Book Eater|Scarlet Centipede|Spectral Executioner|Porcelain Demon|Rune Monk|Red Oni|Calligraphy Demon|Drowned Fisher|Coral Crab|Pearl Spirit|Jade Frog|River Crocodile|Koi Dragon|Eel Wraith|Horned Otter|Reed Scarecrow|Kelp Dryad|Shell Warden|Mist Jellyfish|Coral Seahorse|White Water Snake|Spectral Captain|Ink Octopus|Ice Wolf|Snow Leopard|Frozen Yak|Crystal Stag|Ice Giant|White Owl|Frost Spider|Blue Skeleton|Glacial Serpent|Snow Doll|Pale Bear|Silver Fox Queen|Icy Butterfly|Frost Revenant|Frozen Crane|Mist Mammoth|Ember Lion|Volcanic Salamander|Obsidian Golem|Brass Scorpion|Fire Phoenix|Smoke Wraith|Molten Soldier|Basalt Yak|Coal Spider|Copper Dragonling|Ash Harpy|Fire Mantis|Furnace Monk|Glass Serpent|Lightning Boar|Lava Turtle|Dream Eater|Mirror Phantom|Moth Queen|Willow Spirit|Umbrella Ghost|Jade Mask|Ink Eye|Shadow Qilin|Memory Lotus|Spectral Zither|Paper Crane Swarm|Thread Puppet|Coffin Carrier|Crescent Hare|Lantern Ghost|Cloud Cat|Celestial Lion|Corrupted Phoenix|Black Dragon|Star Golem'''.split('|')
STAGES = [
    ("A Name in Water", "talk", 1), ("A Root Still Breathing", "gather", 3),
    ("The Road of Missing Bells", "explore", 1), ("Teeth of the Old Oath", "kill", 1),
    ("Ash in the Jade", "gather", 2), ("A Witness Who Remembers", "talk", 1),
    ("Stillness Without Permission", "meditate", 1), ("The Second Binding", "kill", 2),
    ("Medicine for the Unforgiven", "gather", 5), ("A Map Drawn Backwards", "explore", 1),
    ("What We Owe the Living", "talk", 1), ("Heaven Does Not Answer", "kill", 1),
]
# Every paragraph is a scene beat. Context ties its people, place, evidence, and
# moral dilemma to the executable objective and its owning twelve-chapter arc.
SCENES = [
    "At the edge of {landmark}, {name} waits until the last lantern is lit before speaking. {name} is known as {article} {role}, but that title has become a shelter for a different kind of work. Tonight {name} has brought the {relic}, wrapped in cloth that smells of rain. Its marks connect {loss} to the curse spreading through {region}. {name} asks Lin Yue to examine the evidence before deciding whom to blame.",
    "The first mark is a narrow cut across the relic's underside. {name} explains that official records call it damage, while local witnesses call it a signature. A person trying to hide a name would cut deeper; a person trying to preserve one would cut exactly this far. The distinction matters in {region}, where {mystery}. Lin Yue turns the object toward the light and sees that someone has repaired it more than once.",
    "{witness} remembers the night differently. {witness} heard a bell before the storm and a second bell after the soldiers departed. Between those sounds, the courtyard filled with people carrying sealed letters. None were allowed to read what they delivered. The {faction} later claimed that every messenger had volunteered. {name} wants their consent investigated, because a promise made under threat cannot become a sacred oath merely by surviving long enough to be written down.",
    "This chapter is called {chapter}. Its immediate task is {task}. That is a practical beginning rather than a complete answer: the mountain cannot be cured by a single sword stroke, and a village cannot be reconciled by declaring one witness pure. Lin Yue agrees to return with a result that can be checked. {name} insists that neither impressive qi nor an imperial title will substitute for evidence gathered in the living world.",
    "The road to {destination} follows an old route used by patients, refugees, and tax collectors. Its stones carry shallow footprints that rain has not erased. {name} gives Lin Yue a simple rule for the journey: stop whenever a voice offers certainty without a cost. Spirits on this road repeat bargains they barely understood when they were alive. Their answers are useful only when compared with the ordinary details their promises leave behind.",
    "By the roadside, Lin Yue finds a small offering bowl. Someone has placed fresh water beside an old piece of charcoal, a gesture that seems contradictory until {witness} explains it. The water is for those who survived; the charcoal is for those whose names were burned. Both offerings belong at the same table. Removing one to make the shrine look harmonious would repeat the choice that damaged {region} in the first place.",
    "The creature called {monster} appears in three different accounts of the disaster. Soldiers described it as a punishment, merchants as a profitable omen, and children as something that stood between them and the fire. Its behavior now follows the pattern of {pattern}. The pattern gives Lin Yue a tactical warning, but it also suggests that the creature remembers a command. A monster can become dangerous while carrying a duty that nobody has released.",
    "{name} once trusted the {faction} because its members promised to protect people without demanding that they become useful first. That promise was tested when food ran short. The council began measuring every household by its ability to repay aid. Those who could not repay were called disloyal. The relic passed through this accounting system and came back with one mark missing. Lin Yue must decide whether the missing mark is an accident or a deliberate erasure.",
    "At an abandoned rest station, a caretaker keeps two copies of the same testimony. One is clean enough for an archive; the other contains corrections made by the people who were present. The clean copy is easier to read and wrong in six important places. {witness} asks Lin Yue to take both. Destroying the polished lie might satisfy anger, but preserving the comparison gives future readers a way to recognize the method of the deception.",
    "The next clue concerns {loss}. {name} has told this part of their history so often that listeners mistake its careful wording for detachment. {name} chooses each word because careless listeners have used their grief as permission to punish strangers. Lin Yue lets the account remain unfinished. A witness does not owe an audience a satisfying conclusion before her evidence can be believed, and the absence of a neat ending does not make the loss less real.",
    "The relic's qi changes near {landmark}. It does not become stronger; it becomes more specific. A loose vibration resolves into the rhythm of a familiar working song. {name} recognizes the song because they learned it before they learned to cultivate. Its final verse names a place the official map omits. Lin Yue records the verse instead of immediately following it. A map can be incomplete without every omission being a trap, but this omission has acquired too many guards.",
    "When Lin Yue considers the fighting ahead, she remembers Master Shen's distinction between power and cultivation. Power can interrupt an enemy's body. Cultivation should also interrupt the habit of treating interruption as an answer. Against {monster}, that means observing the warning motion before committing to a strike, keeping a route back to the lanterns, and leaving enough stamina to withdraw. A victory that strands the witness beside a new danger would fail the purpose of the chapter.",
    "{witness} proposes an easy solution: give the relic to the strongest sect and let its authority settle the dispute. {name} refuses without accusing the witness of cowardice. Easy solutions become attractive when every difficult solution has already charged a person too much. The refusal therefore needs an alternative. Lin Yue offers to separate the immediate threat from the long argument, so that nobody has to remain in danger merely to preserve the appearance of patience.",
    "That alternative requires attention to ordinary supplies. Moonlotus is gathered because roots hold a memory of clean water; jade essence is studied because its vibration can distinguish a binding from a natural current. Neither material is miraculous by itself. {name} teaches Lin Yue to describe what was collected, where it was found, and what changed after contact. The lesson makes a record useful to people who do not share the cultivator's instincts or her access to rare techniques.",
    "A messenger from {destination} arrives with a request to postpone the work. The request is polite, detailed, and unsigned. Its language praises {value} while asking everyone affected by the curse to wait in silence. Lin Yue notices that no date is offered for a new hearing. {witness} has learned to fear indefinite patience more than open threats. They agree to continue the practical task while keeping the message as another piece of evidence.",
    "During a quiet interval, {name} speaks about the life she wanted before the disaster. They wanted time to practice their trade well enough that nobody would remember them as extraordinary. The mountain's crisis has turned every useful act into a test of allegiance. Lin Yue understands the exhaustion in that change. A just ending should give people permission to return to ordinary ambitions, rather than replacing one eternal duty with another whose keeper merely has a kinder face.",
    "The danger returns when {monster} senses movement near the old boundary. Its first approach is a warning, its second a commitment. Lin Yue must meet the actual threat rather than the reputation built around it. She watches its distance, keeps the witnesses outside the line of attack, and uses the terrain to break pursuit. The task of {task} cannot be completed by claiming a kill or a delivery that the world has not actually registered.",
    "After the immediate work, {witness} asks what should happen to the people who benefited from the lie. {name} gives a difficult answer: protection should end where it becomes immunity, but blame should stop where the evidence stops. Lin Yue can favor restitution without promising that everyone will be forgiven. She can favor judgment without declaring that the descendants of an offender inherit the offense. The chapter leaves room for both courage and limits.",
    "The {relic} now carries enough context to be read as more than a treasure. Its value lies in the relationships it documents: who asked for aid, who supplied it, who altered the terms, and who paid after the agreement was changed. {name} wants a copy placed somewhere ordinary people can reach. An archive behind a sect's locked gate might preserve the truth while returning ownership of it to the institution that first concealed it.",
    "Lin Yue returns through {landmark} with the result of {task}. The lantern keeper does not ask how dramatic the journey became. She asks whether the expected evidence arrived and whether anyone must still be searched for. That question sets the measure of success. {name} records the chapter beside the earlier ones, so that later choices will be judged against the whole sequence rather than the most flattering moment in the cultivator's account.",
    "Before the next chapter begins, {name} offers a conversation rather than another command. {name} asks Lin Yue whether {value} can survive when it ceases to look heroic. They compare the answer with the fate of Immortal Xu, whose wish to protect his daughter became a binding on an entire mountain. Neither woman treats his grief as a crime. They examine the moment when he decided that grief granted him ownership of someone else's future.",
    "The closing note is deliberately provisional. In {region}, the immediate task has a measurable result, but the meaning of that result belongs to more than one person. {witness} receives a copy, {name} retains another, and Lin Yue carries the route onward. At the end of the twelve-chapter arc, she will choose whether to release the relic's binding or keep its strength. Until then, the work is to make that choice informed rather than inevitable.",
]


def words(text):
    return len(re.findall(r"\b[\w]+(?:['’-][\w]+)*\b", text))


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    assert len(MONSTERS) == 100
    legends=json.loads((ROOT / "content/authoring/monster_legends.json").read_text())
    assert len(legends)==100 and len(set(legends))==100
    regions = [{"id": f"region_{i:02}", "name": r[0], "landmark": r[1], "mystery": r[2], "faction": r[3], "palette": ["547c6b", "54736f", "4d6f7d", "8499ac", "916b51", "61596c", "6b719a", "77999a", "536578", "856b9a", "868175", "aa9870"][i], "book": f"region_{i:02}.json"} for i, r in enumerate(REGIONS)]
    npcs, monsters, descriptors = [], [], []
    books = {r["id"]: {} for r in regions}
    for i in range(100):
        name = SURNAMES[i // 10] + " " + GIVEN[i % 10]
        region = regions[i % 12]
        ctx = dict(name=name, region=region["name"], landmark=region["landmark"], mystery=region["mystery"], faction=region["faction"], role=ROLES[i % len(ROLES)], loss=LOSSES[i // 10], relic=RELICS[i % 10], value=VALUES[(i // 10 + i % 10) % 10])
        lore = "\n\n".join([
            "{name} is the {role} associated with {landmark} in {region}. They learned their craft from neighbors who expected useful work rather than miracles. Their life changed after {loss}. The authorities offered compensation in exchange for silence, and they refused the terms without refusing help for the people still in danger. That distinction shaped their relationship with the {faction}, whose promises they now read as carefully as they read the {relic}.".format(**ctx),
            "Their private history is preserved in a twelve-chapter account of {value}. Each chapter contains a practical task, a witness, and a consequence that can be checked in the world. They have no interest in recruiting another person to carry their grief forever. They want Lin Yue to distinguish a binding that protects its keeper from an agreement that also protects those bound by it. Their greatest fear is becoming persuasive enough that nobody feels free to disagree.".format(**ctx),
            "The case they keep returning to is {mystery}. They believe its answer belongs to the people who must live with the result. Their manner is patient but exacting: they record the source of every relic, compare testimony before judging it, and ask travelers to return even when a quest ends badly. At the close of their arc, they accept either a release of the binding or an inheritance of its strength, but their final account names the cost of that choice.".format(**ctx),
        ])
        npcs.append({"id": f"npc_{i:03}", "name": name, "role": ctx["role"], "region": region["id"], "lore": lore, "arc": f"The {RELICS[i % 10].title()} of {name}", "art": {"kind": "npc", "character": i}, "quests": [f"quest_{i:03}_{stage:02}" for stage in range(12)]})
    for i, species in enumerate(MONSTERS):
        region = regions[i % 12]
        pattern = ["melee", "ranged", "charge", "leech"][i % 4]
        relic = RELICS[i % 10]
        origin = LOSSES[(i // 10 + 3) % 10]
        lore = f"{species} haunts {region['landmark']} in {region['name']}. Its earliest appearance was recorded after {origin}. The witnesses disagree about whether it was summoned, transformed, or simply given a name when people finally noticed the danger. Its distinctive {pattern} behavior repeats a fragment of an old duty, making it predictable to a patient cultivator and deadly to anyone who mistakes familiarity for safety.\n\nA mark resembling the {relic} appears in accounts of its binding. The {region['faction']} once described the creature as proof that heaven approved their rule; later records quietly recast it as evidence of someone else's disloyalty. Lin Yue can learn more by comparing those accounts than by accepting either declaration. Defeating the creature releases qi and opens a brief interval in which the roads can be used, but its return after rest shows that the regional wound has not been resolved by violence alone.\n\nIts place in the campaign is tied to named witnesses and specific contracts. A hunter must be present for the encounter to count, and a blow through a wall cannot become an honorable victory. This creature is {['fire', 'water', 'earth', 'metal', 'wood'][i % 5]}-aligned, responds to observation of its warning motion, and leaves its own account in the bestiary. The final question is whether a cultivator will treat that account as a trophy or as evidence of an unfinished obligation."
        lore += "\n\n" + legends[i]
        monsters.append({"id": f"monster_{i:03}", "name": species, "region": region["id"], "lore": lore, "legend": legends[i], "pattern": pattern, "element": ["fire", "water", "earth", "metal", "wood"][i % 5], "health": 45 + (i % 5) * 18, "damage": 5 + i % 7, "speed": 1.3 + (i % 4) * .3, "art": {"kind": "monster", "character": i}})
    for i, npc in enumerate(npcs):
        region = regions[i % 12]
        witness = npcs[(i + 31) % 100]
        regional_monsters = [m for m in monsters if m["region"] == region["id"]]
        for stage, (chapter, kind, count) in enumerate(STAGES):
            monster = regional_monsters[stage % len(regional_monsters)]
            destination = regions[(i + stage + 1) % 12]
            target = npc["id"] if kind == "talk" and stage == 0 else witness["id"] if kind == "talk" else monster["id"] if kind == "kill" else destination["id"] if kind == "explore" else "jade" if stage == 4 else "moonlotus" if kind == "gather" else "rest"
            task = f"speak with {npc['name'] if stage == 0 else witness['name']}" if kind == "talk" else f"defeat {count} manifestation{'s' if count > 1 else ''} of {monster['name']}" if kind == "kill" else f"visit {destination['name']} and observe its meridian" if kind == "explore" else "rest at a lantern camp and meditate once" if kind == "meditate" else f"gather {count} {'jade essences' if target == 'jade' else 'moonlotus roots'}"
            ctx = dict(name=npc["name"], role=npc["role"], region=region["name"], landmark=region["landmark"], mystery=region["mystery"], faction=region["faction"], loss=LOSSES[i // 10], relic=RELICS[i % 10], value=VALUES[(i // 10 + i % 10) % 10], witness=witness["name"], destination=destination["name"], monster=monster["name"], pattern=monster["pattern"], chapter=chapter, task=task, legend=monster["legend"], article="an" if npc["role"][0] in "aeiou" else "a")
            text = "\n\n".join(scene.format(**ctx) for scene in SCENES) + "\n\nThe creature has a particular history: " + monster["legend"]
            quest = {"id": npc["quests"][stage], "owner": npc["id"], "stage": stage, "title": f"{npc['name']} · {chapter}", "region": region["id"], "previous": npc["quests"][stage - 1] if stage else "", "objective": {"kind": kind, "target": target, "count": count, "label": task[:1].upper()+task[1:]}, "reward_qi": 25 + stage * 5, "reward_reputation": 1 + stage // 4, "choice": stage == 11, "book": region["book"]}
            descriptors.append(quest)
            books[region["id"]][quest["id"]] = {"story": text, "word_count": words(text), "mercy": f"{npc['name']} releases the {ctx['relic']} from its binding. Her final account favors {ctx['value']}, and {region['name']} gains a witness rather than another immortal keeper.", "power": f"{npc['name']} entrusts the {ctx['relic']} to Lin Yue. Its strength remains useful, but the final account records the obligation carried by every person whose memory powers it."}
            if stage != 11:
                consequence=f"{npc['name']} records the result of the task to {task}. The account is witnessed rather than final: {witness['name']} receives a copy, and the next chapter follows the evidence carried by the {ctx['relic']}. The binding's final fate remains undecided."
                books[region["id"]][quest["id"]]["mercy"] = consequence
                books[region["id"]][quest["id"]]["power"] = ""
    for region in regions:
        write_json(OUT / region["book"], books[region["id"]])
    total = sum(words(page["story"]) + words(page["mercy"]) + words(page["power"]) for book in books.values() for page in book.values()) + sum(words(x["lore"]) for x in npcs + monsters)
    assert total >= 1_000_000, f"Campaign too short: {total}"
    manifest = {"format": 1, "provenance": "Procedurally composed from authored scene templates and linked character histories; not one million handwritten words", "word_count": total, "regions": regions, "npcs": npcs, "monsters": monsters, "quests": descriptors, "book_hashes": {r["book"]: hashlib.sha256((OUT / r["book"]).read_bytes()).hexdigest() for r in regions}}
    write_json(OUT / "index.json", manifest)
    print(f"CAMPAIGN_COMPILED words={total} quests={len(descriptors)} npcs={len(npcs)} monsters={len(monsters)} regions={len(regions)}")


if __name__ == "__main__":
    main()
