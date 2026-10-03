# The old town: how the best games built stealth cities (Oct 2 2026)

Research notes for the old town: the second district of "the city on the rock". It is a terraced maze 70-90 m high, with six key buildings (a tavern with a cellar, a granite tower-house, the merchant's house that holds the upper-gate key, the watch house, a chapel and a walled garden house), many one-to-three-room houses and about ten men of the night watch. Its rule: "the streets belong to the watch, the roofs are the thief's highway".

## How to read this

Each section covers one game or one body of writing, under the same six headings: **What and why**, **Numbers**, **Techniques**, **What went wrong**, **For the old town** and **Links**. Every number names its source. Facts I could not find are marked "(not found)". The tags follow `scale.md`. **[primary]** means a developer talk, interview, forum post or postmortem. **[secondary]** means journalism, a wiki, a walkthrough or a fan analysis. **[ours]** means our own proposal or derived figure, not a sourced fact. Almost everything is paraphrased, and the few quoted words are design terms coined by their authors. I read GDC talks through slides, transcripts or written reports, not the videos. This file goes with `scale.md` §4 (Life of the Party, Shipping and Receiving, Assassins, the Cradle) and `iberian.md` §2 (the real Alfama, Albaicín and Cáceres). It does not repeat their facts. The 25 rules at the end are the part to build from. Everything above them is the evidence.

---

## 1. Thief: Deadly Shadows: the City hub (Ion Storm, 2004)

**What and why.** This is the closest ancestor of our structure. Between missions the player walks the City: districts joined by load points, with fences, shops, burglable houses, side jobs, faction reputation and the City Watch. Its complaints are the ones we must avoid.

**Numbers.**
- There are 5 hub districts: South Quarter, Docks, Auldale, Stonemarket and Old Quarter. Each holds the entrances to 2-3 missions ([Thief wiki, Mapping the City](https://thief.fandom.com/wiki/Mapping_the_City)) [secondary].
- Stonemarket is itself split into "Plaza" and "Proper" loads ([GameSpy guide](http://pc.gamespy.com/pc/thief-deadly-shadows/guide/page_17.html)) [secondary].
- Old Quarter has 3 gates, each a load point: to Stonemarket (NW), the Docks (SE) and Auldale (NE). Its landmarks are the Keeper Compound (W) and Fort Ironwood (SW), with a guard station in the centre ([Thief wiki, Old Quarter](https://thief.fandom.com/wiki/Old_Quarter)) [secondary].
- The GameSpy guide lists about a dozen burglable places across four districts (the excerpt I read may be partial). Each district has roughly one tavern, one shop or fence and one Watch outpost. Some loot regenerates nightly (GameSpy) [secondary].
- Platform: the original Xbox's 64 MB of RAM. It also shrank Ion Storm's Deus Ex: Invisible War ([PC Gamer, 2022](https://www.pcgamer.com/ion-storm-austins-journey-from-thief-to-thief-by-way-of-deus-ex/)) [secondary].
- District sizes in metres: (not found).

**Techniques.**
- Districts unlock as the story advances. After each mission the player reappears in the nearest district ([Wikipedia](https://en.wikipedia.org/wiki/Thief:_Deadly_Shadows)) [secondary].
- On the map, the cardinal positions of the districts were bent for easier hub navigation and load-zone management ([Thief Series wiki, Mapping the City](https://thiefseries.fandom.com/wiki/Mapping_the_City), read through a search summary because the page was paywalled to the fetcher) [secondary].
- Old Quarter is effectively one street, plus a climbing-glove route from the Fort Ironwood archway onto roofs that reach the fence's flat and a map junction. A cubby-hole next to the fence drops into the Watch outpost (GameSpy) [secondary].
- The hub changes with the story. Later, Keeper Enforcers hunt the streets and invade Garrett's own flat, the only time an enemy enters it. The clocktower falls. Allied Hammerites or Pagans fight the Watch for you (GameSpy; Wikipedia) [secondary].
- In a 2023 interview, project director Randy Smith said the open-world City was the part he was most proud of (Wikipedia, citing the interview) [primary, via secondary].

**What went wrong.**
- **Load zones and fog walls.** The single biggest complaint ([MetaCouncil](https://metacouncil.com/threads/thief-3-deadly-shadows-is-a-good-game-thats-even-better-with-mods.1276/)). Players minded loads even in the middle of a corridor ([Slashdot thread on an Evil Avatar interview](https://slashdot.org/story/06/06/15/1919203/the-downfall-of-the-thief-series)). A fan mod later stitched all nine missions into single maps ([PCGamesN](https://www.pcgamesn.com/thief-deadly-shadows/modder-snatches-away-thief-deadly-shadows-loading-screens)) [secondary].
- **Small and samey.** Critics called it a "squat township" of look-alike districts with few alternative roads ([TechRaptor](https://techraptor.net/gaming/guides/better-with-age-thief-deadly-shadows-15-years-later); Slashdot), and more intimate than urban ([Gaming Pastime](https://gamingpastime.com/thief-deadly-shadows-pc-review/)) [secondary].
- **Load zones as escape hatches.** A 2004 review described late-game crossings as sprints for the next load zone, where nobody follows. It felt the hub concept had been "smothered" mid-development ([review text on GameFabrique](https://gamefabrique.com/games/thief-deadly-shadows/)) [secondary].
- **Repetition and a broken economy.** The same Watch must be evaded on every crossing. Players could hoard gear between missions, so they arrived over-equipped (Slashdot). The hub always ran on Normal difficulty; a fan patch fixed this (MetaCouncil) [secondary].
- **Climbing.** The climbing gloves replaced rope arrows and had few places to be used (TechRaptor) [secondary].
- **The sequel repeated it.** Thief (2014) defended its streaming chunks of "over 100 m by 100 m" as the price of rich art and baked light ([Game Informer, Afterwords](https://gameinformer.com/b/features/archive/2014/04/07/afterwords-thief)) [primary]. Players called it an "anti-open world" (PCGamesN) [secondary].

**For the old town.**
- Keep the old town one map, with loads only at the real gates.
- A load must never wipe a chase.
- Give each district several climbing routes, not one gimmick location.
- Let the hub change with the story.
- Make each quarter look different.

**Links:** see Sources §1.

---

## 2. Thief Gold and Thief II city missions (Looking Glass, 1998-2000)

**What and why.** These are the founding stealth cities, with three layers: streets, rooftops ("the Thieves' Highway") and sewers or canals. They are built from loops more than from size.

**Numbers.**
- **Assassins** (Mike Ryan, with Greg LoPiccolo):
  - The assassins take one of three paths home ([Level Design Book](https://book.leveldesignbook.com/studies/sp/assassins); [walkthrough](https://the-spoiler.com/ACTION/Looking.glass/thief.3/thief05.htm)) [secondary].
  - The mansion is almost half the map, and it was cut down late for memory (LDB) [secondary].
  - On Hard or Expert, an alarm floods the lit streets with about 20 permanently alert guards for the trip home. That is more than the mansion holds (LDB) [secondary].
- **Thieves' Guild** (Sara Verrilli, [credits](http://www.digital-eel.com/zdim/stuff/TDPdesign.htm)): 30 / 37 / 44 sword guards and 8 / 10 / 11 bow guards on Normal / Hard / Expert ([Thief wiki](https://thief.fandom.com/wiki/OM_TG_Thieves%27_Guild)) [secondary].
- **Ambush!**:
  - The start square has 3 exits.
  - Garrett's building has 3 ways in: the front door, the fire escape, and a leap from the window opposite.
  - Total loot is 592 ([Thief-TheCircle](http://www.thief-thecircle.com/guides/keeperchapel/Ambush!/); [Alex Fung](http://alexfung.info/favorite/game.t2/t205.html)) [secondary].
  - "Trace the Courier" reuses the map, played at speed ([Cheetham](https://joncheetham.medium.com/the-almost-perfect-level-design-of-thief-ii-the-metal-age-c3bacee98e0d)) [secondary].
- **Life of the Party** (Emil Pagliarulo):
  - It is mission 10 of 15. A careful player needs an hour or more just to reach Angelwatch ([Keverne 1](https://gropingtheelephant.com/blog/?p=2771), [9](https://gropingtheelephant.com/blog/?p=3776)) [secondary].
  - Angelwatch's gallery has 4 entry points, and its 4th floor can be reached 5 ways ([Keverne 6](https://gropingtheelephant.com/blog/?p=3100)) [secondary].
- **Framed**: the mission map runs to 5 labelled pages ([Andrew Yoder](https://andrewyoderdesign.blog/2015/09/11/on-thiefs-level-design-maps-and-territories/)) [secondary].

**Techniques.**
- **Public outside, private inside.** Every mission starts in safe public territory and asks you to case a guarded private one. Assassins flips this, so the public city turns hostile (LDB) [secondary].
- **A few loops feel like a labyrinth.** Gridless, unsigned streets with a handful of loops are enough to feel vast (LDB) [secondary].
- **Sound as a map.** Stone, metal and wood floors sit side by side. Counting an unseen enemy's metal footsteps tells you how long a catwalk is (LDB) [secondary].
- **Buildings as bounded encounters.** In Life of the Party each building has household guards who don't follow you across the roofs. One mistake can't snowball, and the next roof resets the danger (Keverne 1) [secondary].
- **Rising difficulty.** Angelwatch has undousable electric lights, gas lamps the guards relight, hard floors and more guards. The climb up its six floors is a climb "into light" (Keverne 1, 6) [secondary].
- **Shadow from structure.** Beams and lintels cast the shadows in lit corridors. A shadowed door lets you watch a room before committing (Keverne 6) [secondary].
- **Through-houses.** You cross a few rooms of one building just to reach the next. That gives an impressionistic sense of a whole district (Keverne 9; [Casing the joint](https://gropingtheelephant.com/blog/?p=204)) [secondary].
- **Wealth in the surfaces.** Rich places have noisier floors and undousable lamps; poor streets have soft ground and dousable torches ([Game Developer](https://www.gamedeveloper.com/design/thief-tense-narrative-through-level-design-and-mechanics)) [secondary].
- **Architecture as character.** Bafford's showy house is set against Ramirez's spartan villa with spy-holes. A readable reveals that Bafford owes Ramirez money (LDB) [secondary].
- **Partial maps.** Maps are partial on purpose. Thief 3 dropped the "you are here" marker, so players read room function to orient themselves (Yoder) [secondary].
- **Systems, not scripts.** Pagliarulo placed patrols so that small scenes happen naturally ([TTLG, 2000](https://www.ttlg.com/forums/showthread.php?t=41604)) [primary].

**What went wrong.**
- **Cuts and acoustics in Life of the Party.** Pagliarulo cut demo rooftops because the mission hit the engine's object limit. He sealed Angelwatch's chimneys because a noise on floor 1 alerted floor 4 and then everyone. The party is "winding down" because 20-40 active AI in one room was impractical (TTLG) [primary].
- **Fake doors.** The rooftops are full of locked, fake doors, while every door in Angelwatch opens (Keverne 9) [secondary]. One fan found the stops too short (1-2 rooms each) and the route exhausting ([Thief Guild](https://www.thiefguild.com/topics/106718/a-stupendous-map)) [secondary].
- **Thieves' Guild.** Panned for confusing, same-looking sewers, levers with no clear purpose and a cryptic objective (Thief wiki; [TechRaptor](https://techraptor.net/gaming/features/even-when-its-bad-its-good-defending-thieves-guild-thief)) [secondary].
- **Empty streets.** A veteran player called the Ambush! town "way too empty" ([Klatremus](https://www.klatremus.org/t2/Mission4.htm)) [secondary].
- **Hidden content.** The Assassins escape needs an alarm on Hard or Expert, so most players never see it (LDB) [secondary].

**For the old town.**
- Give each key building its own guards and its own alarm.
- Make the upper town brighter and noisier, with lamps that get relit.
- Make every cistern and drain look different.
- An alarm should change the district's state.

**Links:** see Sources §2.

---

## 3. Dishonored 2: Karnaca (Arkane Lyon, 2016)

**What and why.** The modern benchmark for a sunny Mediterranean city of balconies and flat roofs. It is the nearest look and feel to Iberian terraces.

**Numbers.**
- District sizes and NPC counts: (not found).
- **Royal Conservatory**: at least 3 sanctioned ways past its defences, plus windows and roofs ([Neoseeker](https://www.neoseeker.com/dishonored-2/walkthrough/The_Royal_Conservatory)) [secondary]:
  - an elevated path opened by a side job
  - disabling the Wall of Light
  - a drain behind a garden waterfall
- **The Good Doctor**: judged much more linear than the missions around it ([Polygon](https://www.polygon.com/2016/12/2/13818014/the-good-doctor-walkthrough-stealth/)) [secondary].

**Techniques.**
- **Layering order.** First the main buildings, balconies and apartments; then designers "dig" in, adding or removing entrances and paths ([Critical Hit, quoting Carrier to Eurogamer](https://www.criticalhit.net/gaming/dishonored-2-has-a-layered-and-deeper-approach-to-level-design/); [Eurogamer](https://www.eurogamer.net/dishonored-2s-approach-to-level-design)) [primary].
- **The no-powers test.** Lead level designer Christophe Carrier played maps without powers as much as he could. Hidden routes for powerless players are part of the fun (same) [primary].
- **Not everyone sees everything.** Arkane accepts that players miss whole areas. What it wants is "coffee machine talks": players comparing routes (same) [primary].
- **Pillars.** Carrier's three are immersion, interactivity and consequences. Never lock a player into a stealth lane or a combat lane, and close exploits that skip whole areas ([GamesRadar](https://www.gamesradar.com/dishonored-2s-level-designer-explains-how-to-build-the-perfect-level/)) [primary].
- **Important doors must be seen.** A player who misses a door never knows it existed. Light it, or set the entry angle so it is in view (same) [primary].
- **The first lesson.** The opening office has a second, closed window that can be opened. Players learn to try things they assumed impossible ([Eurogamer](https://www.eurogamer.net/how-dishonored-2-hides-its-best-details-in-the-periphery)) [primary].
- **Flat roofs bring the guards up.** Havana's roof-terrace life inspired flat roofs. Arkane reasoned that guards must be able to follow the player up, so they added a floor to already-tall buildings. Art director Sébastien Mitton called it a nightmare that opened a new condition. The working motto is to say "yes" to the player, so even scenic windmills must be breakable or switchable ([PC Gamer, Mitton](https://www.pcgamer.com/balancing-art-direction-and-level-design-in-dishonored-2/)) [primary].
- **Spanish sources.** Arkane made photo trips to Barcelona and sketched La Rambla's narrow, flat-roofed streets. Siesta street life shaped the mood ([Inverse, Mitton](https://www.inverse.com/gaming/23269-dishonored-2-sebastien-mitton-art-director-arkane-studios-interview)) [primary]. Fictional immigration waves decided each district's architectural era ([ACMI](https://www.acmi.net.au/works/100859--set-design-in-dishonored-2/)) [secondary].
- **One landmark for the whole city.** Shindaerey Peak orients players from anywhere ([PC Gamer gallery](https://www.pcgamer.com/dishonored-2-concept-gallery-with-insights-from-arkanes-art-director/)) [primary]. Vistas were built in 3D per map, keeping building ratios equal between playable space and backdrop. A repeated foreground element sells distance ([80.lv, Gasperin](https://80.lv/articles/modular-design-in-dishonored-2)) [primary].
- **Dust District.**
  - The mine is upwind, so dust storms blow through the streets and give stealth cover (ACMI) [secondary].
  - Two factions, the Howlers and the Overseers, split the district ([Bethesda](https://bethesda.net/en-US/news/dishonored-2-howlers-vs-overseers)) [primary]. There are two possible targets ([GameBanshee, Harvey Smith](https://www.gamebanshee.com/news/117972-inside-the-epic-themed-missions-of-dishonored-2.html)) [primary].
  - The storm's sound arrives in stages. The audio team avoided "fake sounds" that would point players at places that don't exist ([Designing Sound](https://designingsound.org/2017/02/22/dishonored-2-interview/)) [primary].
- **Nodes that gather routes.** In Edge of the World, Canal Square is where separate starting paths meet before branching again. Balcony guards watch the crowd below, not the balconies ([Polygon](https://www.polygon.com/2016/12/2/13817994/edge-of-the-world-walkthrough-stealth/)) [secondary].
- **Vantage points and affordances.** A student study found Arkane's strongest guidance tools were safe overlooks and affordances such as broken railings that invite a climb ([Jimmy Lu](https://jimmylu.net/dishonored-level-project/)) [secondary].
- **Clockwork Mansion.**
  - No long, tight passages inside the walls, because those confuse players most.
  - Backstage spaces stay visually connected to the big rooms.
  - Every room keeps a real-world function, so the house can be inferred without markers ([Game Developer deep dive](https://www.gamedeveloper.com/design/level-design-deep-dive-i-dishonored-2-s-i-clockwork-mansion)) [primary].
  - A Crack in the Slab tells its owner's life through readables ([Kotaku](https://kotaku.com/what-made-dishonored-2s-time-travel-level-so-good-1819596566)) [secondary].

**What went wrong.**
- Flat, reachable roofs forced a structural rework, and powerful movement forced "bullet-proofing" of every area (PC Gamer; GamesRadar) [primary].
- The Good Doctor was criticised as linear (Polygon) [secondary].
- Talks by Dinga Bakaba or GDC sessions on Karnaca's districts: (not found).

**For the old town.**
- If the player can reach a roof terrace, the watch can too, and the player can see how.
- One global landmark (the castle above, the sea below) gives "up" and "down" from anywhere.
- Build the shell first, then dig the routes in.
- Test every key building without consumables.

**Links:** see Sources §3.

---

## 4. Dishonored (Arkane, 2012)

**What and why.** It perfected the street-to-rooftop-to-interior mission over a revisited city, and gives the clearest numbers on entrances.

**Numbers.**
- **The Golden Cat**: the co-directors said there were eight to nine ways in ([Gameranx on the E3 2012 videos](https://gameranx.com/updates/id/7640/article/bethesda-shows-two-ways-to-play-dishonored-in-this-golden-cat-walkthrough/)) [primary, via secondary]. Guides list the front door, a rat vent, a balcony, the window above it, an underwater tunnel and two roof crossings from the Captain's Chair hotel ([gamepressure](https://www.gamepressure.com/dishonored/infiltrating-the-golden-cat-club/z041b9); [Dishonored wiki](https://dishonored.fandom.com/wiki/House_of_Pleasure)) [secondary].
- **The twins' rooms**: at least 4 independent clue sources reveal them. There are two ledgers, an eavesdrop on the madam and a guard, and a washroom conversation between courtesans (Dishonored wiki) [secondary].
- **Lady Boyle's Last Party**: three near-identical sisters, and the target changes each playthrough. Diaries, conversations and habits identify her ([PC Gamer](https://www.pcgamer.com/the-making-of-dishonoreds-greatest-mission-lady-boyles-last-party/)) [primary].

**Techniques.**
- **Grey space.** Harvey Smith calls the run-down streets before the party "grey space", full of apartments to explore. He seeks contrast on every axis: class, action, cleanliness, light ([DualShockers](https://www.dualshockers.com/making-of-dishonored-harvey-smith-raph-colantonio/)) [primary].
- **"Messy" worlds.** There is no "stealth corridor": routes are blended into an organic, non-grid European city (PC Gamer) [primary].
- **Plausibility.** Every place has a history, and every guard needs a sensible way to his post. Smith's warning example is a route of a mile and ten flights of stairs ([Game Developer](https://www.gamedeveloper.com/design/-i-dishonored-i-s-harvey-smith-player-choice-is-paramount-in-design)) [primary].
- **Side jobs open routes.** Slackjaw's errand pays with the key to the Captain's Chair hotel and its roof route (Dishonored wiki) [secondary].
- **The district remembers.** On return, the Distillery District has a new watchtower, explained by the previous mission's outcome. Bottle Street is a neutral gang zone where the player may walk freely (same) [secondary].

**What went wrong.**
- **Outside versus inside.** Raphaël Colantonio said a building always looks too big from outside and too small inside. The Hound Pits pub became a labyrinth of stairs, so they bricked up its third floor ([Eurogamer 2012, archived](https://web.archive.org/web/20200607215321/https:/www.eurogamer.net/articles/2012-11-07-peeling-back-the-layers-of-dishonored-with-harvey-smith-and-raph-colantonio)) [primary].
- **Over-signposting.** Playtesters would not go upstairs at Boyle's party because guards told them not to. The final game nags "go upstairs", and a critic called that its one weakness ([Kotaku](https://kotaku.com/dishonoreds-party-level-rewrote-the-rules-of-stealth-ga-1613011624)) [secondary].
- **Scale.** Walkable areas are not broad; complexity and long views carry the world ([Game Developer](https://www.gamedeveloper.com/design/postmortem-the-level-design-of-dishonored-series)) [secondary].

**For the old town.**
- Give each key building several entries.
- Tell each critical fact three or four ways.
- At least one side job should pay out a route.
- Blind or brick unused upper floors honestly.

**Links:** see Sources §4.

---

## 5. Hitman (2016): Sapienza, plus Marrakesh (IO Interactive)

**What and why.** Sapienza is a dense, vertical Italian cliff town with many enterable houses, built around a public town and a private mansion. It is the closest real-world typology to our terraces.

**Numbers.**
- **Population.** Levels hold about 300 NPCs ([Wikipedia](https://en.wikipedia.org/wiki/Hitman_(2016_video_game))) [secondary]. A fan count puts Sapienza at 299 named NPCs, Paris at 300 and Marrakesh at 290, with the crowd excluded ([Hitman Forum](https://www.hitmanforum.com/t/does-anyone-know-how-many-npcs-are-in-the-h3-maps/7009?page=2)) [secondary].
- **Blockout.** Two people mocked up the rough level in about two weeks ([PC Gamer](https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/)) [primary].
- **Size.** Paris is larger in square metres but "feels smaller", because a palace can be mapped mentally and a town cannot ([IBTimes, Elverdam](https://www.ibtimes.co.uk/hitmans-game-director-season-finale-japan-sapienza-his-favourite-kill-season-1589102)) [primary]. Sapienza's area: (not found).
- **Underground.** The sewer's main path runs from the beach to the graveyard, with junctions to a well, a basement, the church restrooms, the catacombs, the church basement and the morgue: 6+ exits ([Ludo guide](https://www.ludo.guide/guide/hitman-world-of-assassination/hitman-world-of-assassination-part-87)) [secondary].

**Techniques.**
- **Swiss cheese and the snail house.** The town is a volume full of connections, so you never get lost. Spirals of streets and stairs mean there are no dead ends and no forced backtracking ([PC Gamer](https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/); [Game Developer](https://www.gamedeveloper.com/design/-i-hitman-i-dev-says-the-secret-to-expansive-level-design-is-spirals)) [primary]. Rooms flow so players don't miss stairwells ([RPS](https://www.rockpapershotgun.com/how-hitmans-hokkaido-level-was-made)) [primary].
- **Contained pressure.** The town is deliberately quiet, a "siesta" feel. Danger sits in the mansion; the town holds weapons, secret routes and opportunities ([PC Gamer p.2](https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/2/)) [primary].
- **Short loops.** A target's loop through the church and the cave tested playtesters' patience. Both targets' loops were shortened and confined to the mansion, with lures added (PC Gamer p.2) [primary].
- **Purposeful NPCs.** Every NPC is placed with a purpose. The disguise-spotting "enforcers" are added late and their gaze tuned many times (same) [primary].
- **A vantage landmark.** The church bell tower overlooks the villa ([Gamereactor](https://www.gamereactor.eu/hitman-sapienza-preview/)) [secondary].
- **Six social spaces.** Level designer Mette Podenphant Andersen classifies spaces as public-open, public-purpose, public-rule, private, professional and personal ([PC Gamer, 2019](https://www.pcgamer.com/how-the-creators-of-hitman-use-social-science-to-design-perfect-murder-playgrounds/)) [primary]. Her model draws on Goffman's front stage and back stage. Players read the rules from the space, such as an ice-cream counter you must not walk behind. Hitman 2 enlarged its public areas and budgeted unique art for the back-stage spaces.
- **Believable walls.** Research used YouTube and Street View of Vernazza. Walls were thinned to fit the window-throw animation, but structures must still look able to carry their own weight ([PCGamesN](https://www.pcgamesn.com/hitman/hitman-hokkaido-sapienza-design-interview)) [primary].
- **Marrakesh.** IO aimed at "overloading of the senses" with crowds ([Gamereactor](https://www.gamereactor.eu/reflecting-on-hitman-season-one-with-io-interactive/)) [primary]. The map has alleys, souks, a shisha café and rooftop terraces ([PlayStation Blog](https://blog.playstation.com/2016/05/25/hitman-episode-3-marrakesh-launches-may-31/)) [primary].

**What went wrong.**
- Long target loops; fixed as above.
- Trespass first triggered combat. Being escorted back to public space was added after testers found it too punitive (Wikipedia) [secondary].
- Colorado was disliked for having no public space and no verticality (same) [secondary].

**For the old town.**
- Stair-lanes should spiral the rock.
- Lower squares are public-open, the tavern is public-rule, and key buildings are private.
- Patrols should be readable in about a minute.
- A sparse night population is believable and affordable.

**Links:** see Sources §5.

---

## 6. Deus Ex (2000), Human Revolution (2011), Mankind Divided (2016)

**What and why.** The canonical hubs with revisits and world memory.

**Numbers.**
- **Hell's Kitchen** is visited 3 times and changes each time ([Deus Ex wiki](https://deusex.fandom.com/wiki/Hell%27s_Kitchen)) [secondary]:
  - First visit: a street fight, with civilians sheltering indoors.
  - Second visit: streets cleared; Osgood's boarded up and the clinic closed.
  - Third visit: Osgood's burnt out, robots running the clinic, riot police patrolling.
- **Deus Ex maps** were cut into small pieces after big areas ran slowly ([Spector postmortem](https://www.gamedeveloper.com/design/postmortem-ion-storm-s-i-deus-ex-i-)) [primary].
- **Invisible War's** "slum" of Lower Seattle shipped as a couple of streets, three apartments, a coffee shop and a quiet bar, because of the Xbox's 64 MB ([PC Gamer](https://www.pcgamer.com/ion-storm-austins-journey-from-thief-to-thief-by-way-of-deus-ex/)) [secondary].
- **Human Revolution:**
  - Each level targeted about one hour. Every level has a stealth path, and the game is finishable without augmentations. The game, not the player, decides when hubs are revisited ([Worthplaying](https://www.worthplaying.com/article/2011/8/11/previews/82797-deus-ex-human-revolution-all-a-day-at-eidos-montreal-update-5/)) [primary].
  - About 12 moving and 6 static NPCs could be on screen; Mankind Divided doubled that ([PC Gamer](https://www.pcgamer.com/deus-ex-mankind-divided-power-and-choice-in-cyberpunk-prague/)) [primary].
- **Prague:**
  - Splitting the planned single zone in two was a "very hard decision", made for performance and bridged by metro stations ([Game Developer, Douce GDC 2017](https://www.gamedeveloper.com/design/level-design-lessons-learned-building-i-deus-ex-mankind-divided-i-s-prague)) [primary].
  - The city has 3 states (day, night, curfew) and is visited 3 times (same; [80.lv](https://80.lv/articles/deus-ex-mankind-divided-building-prague-city-hub)) [primary].
  - A preview corner measured about two or three city blocks (PC Gamer, 2015) [secondary].

**Techniques.**
- **One hub per player type.** Prague gives "killers" sub-locations at equal distances and fast travel, "explorers" "deep pockets of exploration", "socialisers" characters to talk to, and "achievers" rewards on ledges, because testers stacked boxes to climb (Douce) [primary].
- **Landmarks at exits.** Monuments are placed so they are seen on leaving buildings or metro stations (Douce) [primary].
- **Side content on the main path.** The "Golden Ticket" side quest is placed across the critical path so every player learns side content exists (Douce) [primary].
- **Acknowledge every choice.** Douce: "choices are all about feedback". Feedback comes through headlines, emails and NPC remarks. A dead shopkeeper's shop gets police tape, then closes for good (Douce) [primary].
- **Hand-made interiors.** One level designer worked only on the stories of hub flats, threading emails between neighbours ([PC Gamer](https://www.pcgamer.com/taking-on-the-slums-with-new-augs-in-deus-ex-mankind-divided/2/)) [primary]. Clémence Maurer's GDC talk covers filling a dense hub cheaply with linked clues ([Game Developer](https://www.gamedeveloper.com/design/video-making-exploration-rewarding-in-i-deus-ex-mankind-divided-i-)) [primary, abstract only].
- **A small team.** Two level artists built the modular kit, the flats and the shops, with no outsourcing. There are 3 distinct architectural areas (80.lv) [primary].
- **Detroit.** Sections are joined by a train, sewers and hidden passages. Each area has a visual identity, and public maps are posted around the city ([Markham](https://xandermarkham.blogspot.com/2011/07/future-shock-deus-ex-human-revolution_28.html)) [secondary]. It was the first location built, drawing on Bloodlines ([GameBanshee](https://www.gamebanshee.com/news/115167-deus-ex-human-revolution-level-design-blog-part-two.html)) [primary].

**What went wrong.**
- Prague loads nothing for its shops, flats or sewers, so everything sat in memory at once. That forced the split and a "mental database" of workarounds (Douce; 80.lv) [primary].
- Each branching side quest needed a full-time designer and writer (Douce) [primary].
- Many Detroit NPCs had nothing to say (Markham) [secondary].

**For the old town.**
- District memory should be cheap and visible: boards, notices, an extra guard.
- Post one public map, an azulejo street-plan panel at the harbour gate [ours].
- Spend storytelling on flats that link to each other.

**Links:** see Sources §6.

---

## 7. The Dark Mod and the fan-mission scene

**What and why.** Community missions are where Thief-style towns kept evolving, and their reviews show what players praise and resent.

**Numbers.**
- **The Painter's Wife** (2020): one player spent 7+ hours ([Thief Guild](https://www.thiefguild.com/topics/75034/be-prepared)). Its town has 4 entries into the sewers, one needing no lockpick or key ([Klatremus](https://www.klatremus.org/TDM_PaintersWife.htm)) [secondary].
- **Volta 3: Gemcutter** (Kingsal, 2024) has a Moorish-architecture city ([TDM wiki](https://wiki.thedarkmod.com/index.php?title=Fan_Missions_for_The_Dark_Mod)). It won TDM's 15th-anniversary contest, scoring highest on gameplay and visuals. The Lieutenant 3 is set in a Moorish harbour ([ModDB](https://www.moddb.com/mods/the-dark-mod/news/happy-holidays-from-the-dark-mod)) [secondary].
- **Thief: The Black Parade** (2023): 10 maps, about 20 hours, 1,800 voice lines. Its lead worked at Arkane ([Backloggd](https://backloggd.com/u/PerrySimm/review/2370494/); [Reload](https://reload-magazine.net/articles/thief-the-black-parade-mar-2025)) [secondary].
- Layouts of A New Job, Lords & Legacy and A House of Locked Secrets: (not found).

**Techniques praised.**
- **Painter's Wife.**
  - A Life-of-the-Party town opened into a sandbox, with several approaches to the target.
  - Even the critical path forces back-and-forth across town, so players stumble on side stories, one of which ties to the main goal.
  - Every location is coherent and distinct ([Thief Guild review](https://www.thiefguild.com/topics/106718/a-stupendous-map)) [secondary].
  - Players praise its verticality, the many windows to climb in, and that it never feels circular (Poorman) [secondary].
- **Black Parade.** A window seen from the street really connects, via pipes, across buildings. Important objects are signposted by sound, such as a ticking clock (Reload) [secondary].
- **Pseudo-natural levels.** Players infer contents from type: a house has kitchens and cellars, a cathedral a bell tower. The joy is spotting a ledge and popping up where you shouldn't be ([Patrick Stuart](https://pjamesstuart.substack.com/p/thief-and-butterfingered-infinity)) [secondary].

**What went wrong.**
- **Painter's Wife.** Most side activities are 1-2 rooms or key hunts, and some are signposted too vaguely. There is little loot, because so much surface is connective street, and the connections are hard to keep track of (Thief Guild review) [secondary].
- **Black Parade.** Single-solution objectives hidden where nothing points frustrate players ([TV Tropes review](https://tvtropes.org/pmwiki/review_comments.php?id=22891)) [secondary].
- **Generally.** Roaming endlessly for one obscure key drives players off ([Old PC Gaming](https://oldpcgaming.net/thief-the-dark-mod-review/)). Painted-on doors at the edges expose urban levels (Stuart) [secondary].

**For the old town.**
- No 1-2-room key hunts.
- Put loot along the streets too.
- Signpost optional jobs clearly.
- Make fake doors visibly barred.

**Links:** see Sources §7.

---

## 8. Level-design writing

### 8.1 Randy Smith: "Level Building for Stealth Gameplay" (GDC 2006) and Thief stealth fundamentals (GDC 2002)

Read through the slides, a transcript of the 2006 audio, and the 2002 slides.

**What and why.** The Thief director's own vocabulary for stealth spaces. **Numbers:** none; it is a vocabulary talk.

**Techniques** [primary unless noted] ([slides](https://www.slideserve.com/libitha/level-building-for-stealth-gameplay-powerpoint-ppt-presentation); [transcript](https://www.youtube.com/watch?v=XrUNCn8OxcY)):
- **The goal.** Create the illusion of a securely guarded area that the player sneaks through by exploiting its flaws.
- **A path to zero failure.** Every encounter needs a path with no failure, communicated but not too obviously. Too much help and the player doesn't feel stealthy; too little and they feel incapable.
- **Design tools.** Scouting locations, connectivity, shadows, guards, loud flooring, dead ends. Players are drawn to shadowy alcoves, which makes alcoves a pacing tool.
- **Scouting locations.** Smith's "most important" idea: safe spots for seeing the next challenge and forming a plan, such as crossroads, balconies, rafters and high ground. Turn blind corners into scouting spots. A scouting spot must look safe; his brightly lit balcony went unused.
- **Islands of shadow.** It works best when everything is a little unfriendly to stealth, broken by islands of safe space. The rhythm of tension and relief matters.
- **Environmental tools are sneaky.** Doors, stairs, furniture and columns change stealth play even when placed only for looks. L-shaped rooms usually beat square ones. A patrol is both a threat and a gap, since a moving guard can't watch the whole room.
- **The bright front gate.** A lit, guarded gate tells the player to find another way in.
- **Gradients, not scripts (2002).** Build "possibility spaces" and avoid absolutes ([2002 slides](https://www.scribd.com/presentation/720268810/RandySmith-GDC-2002)).
- **Analysis, not process.** Looking Glass actually greyboxed, placed guards by intuition and playtested; the vocabulary is for analysis ([Level Design Book](https://book.leveldesignbook.com/culture/unfinished-pages/history-encounter-design)) [secondary].

**What went wrong.** Thief 1's stealth "chemistry" came together only weeks before ship (Slashdot, quoting the Evil Avatar interview) [primary, via secondary].

**For the old town.** Every stair-head, square mouth and roof edge is a scouting spot, and each must look safe.

### 8.2 Christopher Totten: An Architectural Approach to Level Design

- **Prospect and refuge** (after Grant Hildebrand). Prospect space is open and exposed; refuges are enclosed, shadowed or low-ceilinged spots that look out. Travel runs refuge → prospect → *secondary refuge*, which is exactly the shape of stealth. High places can be refuges too ([Game Developer, 2011](https://www.gamedeveloper.com/design/designing-better-levels-through-human-survival-instincts)) [primary].
- **Other tools in the book.** Narrow, intimate and prospect space; architectural "weenies" that draw players; Kevin Lynch's landmarks, paths, nodes, edges and districts; shade and shadow; "loving and hating height" ([Routledge contents](https://www.routledge.com/Architectural-Approach-to-Level-Design-Second-edition/Totten/p/book/9780815361367)) [primary, contents only].
- **For the old town.** Retaining walls are edges, stair-lanes are paths, squares are nodes, the belfry and the gate are landmarks, and the quarters are districts.

### 8.3 Joel Burgess and Nate Purkeypile: "Skyrim's Modular Approach to Level Design" (GDC 2013)

**Numbers** [primary] ([slides](https://www.slideshare.net/slideshow/gdc2013-kit-buildingfinal/17728576); [transcript](http://blog.joelburgess.com/2013/04/skyrims-modular-level-design-gdc-2013.html)):
- 2 kit artists, 8 level designers, 7 kits, 30 months, 400+ unique cells.
- The cave kit was used about 200 times; the Ratway kit twice.
- The cave kit has 7 sub-kits; its small-hall sub-kit has about 50 pieces.
- Scale: 128 units ≈ 2 m.
- Kit phases: concept about 1 week, proof 1-3 weeks, greybox 1-4 weeks.

**Techniques.**
- Set global standards first: doorframes, minimum widths, inclines, jump and cover heights. A uniform doorframe joins kits and gives AI a fixed standard.
- Sub-kit footprints must be multiples of each other (512 with 256, never 384). Keep grid snaps large.
- Don't tile on all axes; make a separate "shaft" sub-kit for vertical stacking.
- Stress-test in ugly layouts.
- Allow one quirk per kit.
- Players notice repeated clutter before repeated architecture ([t-machine notes](https://t-machine.org/index.php/2013/05/04/skyrim-level-design-transcript-notes-from-gdc-2013-talk/)).
- Dishonored 2's Gasperin adds shared tiling textures plus decals to break repetition ([80.lv](https://80.lv/articles/modular-design-in-dishonored-2)) [primary].

**For the old town.** One house kit on one grid, with one quirk per house.

### 8.4 Harvey Smith and Matthias Worch: "What Happened Here? Environmental Storytelling" (GDC 2010)

Players piece the story together from a staged space, and because they pull it at their own pace it engages them ([slides](https://www.slideserve.com/zahur/what-happened-here-environmental-storytelling); [Worch](https://www.worch.com/2010/03/11/gdc-2010/)) [primary]. The rules:
- Establish a discernible chain of events: a cup, an offset chair, a trail of crumbs.
- Make the event engage the player.
- Echo the world's premise.
- Build character.
- Avoid gaps between what the player can do and what was staged.

**For the old town.** Each ordinary house gets one short chain that echoes the district (curfew, debt, rebuilding).

**Links:** see Sources §8.

---

## Principles for the old town

Each rule names its source. Numbers tagged **[ours]** are derived, not sourced.

1. **One map, gates only.** Loads only at the harbour gate and the upper gate. No fog walls, no loads mid-lane. *Sources: the top TDS complaint (§1); Prague's forced split (§6).*

2. **No escape hatches.** Carry the alert level and chasing watchmen across a gate, or make the gates watched chokepoints. *Source: TDS players sprinting for safe load zones (§1).*

3. **Three or more ways into every key building, of different kinds.** A key door, a lockpickable service door, a climb (balcony, window, hatch, chimney) and where plausible a below route (cellar, cistern, drain). *Sources: Golden Cat 8-9 ways in; Conservatory 3+; Garrett's building 3; Angelwatch's gallery 4 (§2-4).* Suggested floors [ours]:
   - tavern 4
   - tower-house 2-3 (granite resists climbing; give it one weakness, such as a latrine chute or a dovecote)
   - merchant's house 4-5
   - watch house 3
   - chapel 3 (nave, sacristy, belfry from the roofs)
   - walled garden house 3 (gate, the wall at a fig tree, a cistern channel)

4. **The upper-gate key has alternatives.** The merchant's key is the clean way. Add a hard lockpick and a physical route over or under the gate, and let a side job unlock one of them. *Sources: Slackjaw's key (§4); the Conservatory's side-job path (§3); Deus Ex's no-augmentation path and Carrier's no-powers testing (§3, §6).*

5. **Every vital fact has 3-4 sources.** Where the key is kept, when the merchant sleeps and how the gate is manned should each come from a readable, an overheard conversation and an environmental clue. Make important doors and objects stand out with light, entry angle or sound. *Sources: the twins' rooms told four ways and Boyle's diaries (§4); Carrier's doors (§3); Black Parade's ticking clock (§7).*

6. **Segment the roof highway.** Roofs chain along each terrace block and break at every lane and square. Crossing a break takes a leap, a bridging element (an arch over a lane, a laundry beam, a plank), a pass through a house, or a descent. Suggested chain: 3-6 houses, about 25-60 m [ours]. *Sources: Life of the Party's building-by-building route and through-houses (§2); Karnaca's balconies (§3).*

7. **Roofs are the thief's, but never absolutely safe.** Every roof chain gets at least one visible watch access (a ladder, terrace stairs, a hatch). At least two roofs are actually used by the watch: the watch-house lookout and the chapel belfry. *Sources: Mitton's rule that guards must follow onto flat roofs (§3); Smith's "communicate the means" (§8.1).*

8. **Households bound their own danger.** The guards and servants of each key building react only inside it. Only the ten watchmen roam and spread an alert. *Sources: Life of the Party's households (§2); Smith on the low threshold for failure (§8.1).*

9. **Loops, not a tree.** Give the street layer 3-5 loops, the roofs 2-3, and an underground of cisterns, drains and linked cellars with 3-4 entrances [ours]. A dead end must pay out loot, a view or a hatch. *Sources: Assassins' "handful of loops" (§2); Sapienza's snail house and 6+ sewer exits (§5); Painter's Wife's 4 sewer entries (§7).*

10. **Terrace connectors are chokepoints.** Each terrace step gets at least 2 public connectors (stair-lanes, ramps) and 1-2 thief connectors [ours]: a climbable retaining wall, a cistern shaft, or best of all a house with doors on two levels. That last one is real in Alfama and Porto, and it is the ideal through-route. *Sources: `iberian.md` §2; Smith on stairs as stealth obstacles (§8.1); Life of the Party's through-houses (§2).*

11. **A scouting spot at every threshold.** Every stair-head, square mouth and terrace edge gets a shadowed, parapeted refuge that overlooks the next space. Turn blind corners into lookouts, and never light a lookout. *Sources: Smith's scouting locations (§8.1); Totten's prospect and refuge (§8.2); Arkane's vantage points (§3).*

12. **Three tiers of landmark, seen from every exit** [ours: spacing, for a district about 250-350 m across].
    - **Global:** the castle above and the sea below, for "up" and "down" from anywhere, as Shindaerey Peak does (§3).
    - **District:** the belfry, the granite tower, the watch-house lantern and the upper gate, about 60-120 m apart, so one is visible from every square and roof chain.
    - **Local:** fountains, shrines and azulejo panels, one per node.

    Place district landmarks so they are seen on leaving every key building and on entering by each gate. *Source: Prague's monuments at exits (§6).*

13. **Difficulty rises with altitude.** The lower town is poor and dark, with dousable torches, soft ground and more civilians. The upper town near the merchant and the gate is brighter, with noisy tile and flagstone floors and lamps the watch relights. *Sources: Thief's wealth-coded surfaces; Angelwatch's ascent "into light" and its relit lamps (§2).*

14. **Islands of shadow in a lit street.** Streets are a little unfriendly by default: watch lamps, tavern doors, moonlit whitewash. They are broken by islands such as dark doorways, arcades and the shadow under a stair, spaced so the player can hop between them and rest. *Sources: Smith's islands and tension-relief cycle (§8.1); `iberian.md` on whitewash at night.*

15. **Control the acoustics.** Teach the surfaces once by putting three side by side. Keep sound from crossing whole buildings by segmenting stairwells and shafts. Let only the tavern's noise mask the player. *Sources: Assassins' three-material catwalk; Angelwatch's sealed chimneys (§2).*

16. **Ten watchmen, short loops.** Suggested split [ours]:
    - 2 at the upper gate
    - 2 at the watch house, one inside and one on its roof lookout
    - 4 in two paired street patrols, one lower and one upper
    - 1 in the belfry or on a terrace lookout
    - 1 roving sergeant who relights lamps and checks doors

    Each cycle should be observable in about 45-90 s [ours]. *Sources: Hitman's shortened loops (§5); Smith's plausible routes to every post (§4); L-shaped turns that open gaps (§8.1).*

17. **The district remembers, cheaply and visibly** [ours]. Doused lamps are relit later. Burgled houses are boarded, with a notice on the door. A theft at the merchant's adds a man at the gate. A full alarm switches the district into a curfew state with doubled patrols and shut shutters. *Sources: Hell's Kitchen's three states; Prague's curfew state; the Distillery watchtower; the invaded flat in TDS; the alert guards of Assassins (§1, §2, §4, §6).*

18. **Ordinary houses are worth entering.** Each enterable house offers at least two of four things [ours]:
    - a route: it links two terraces, or a street to a roof
    - a view: it overlooks something worth scouting
    - a story: one chain of events, plus a readable naming a neighbour
    - a reward: a little loot, a lockpick, a flask refill, rope

    No house exists only as a key hunt. *Sources: Worch and Smith (§8.4); Prague's linked flats (§6); the critique of Painter's Wife (§7); Life of the Party's through-houses (§2).*

19. **Some houses are occupied.** About a third of ordinary houses hold a sleeper or an insomniac, a witness who can wake and shout for the watch [ours]. Night justifies a sparse cast. *Sources: the "winding down" party (§2); Sapienza's quiet town (§5); Deus Ex's NPC budgets (§6).*

20. **Readable social space.** Tag every blockout space by Andersen's six types. The lower squares are public-open, a safe place to get bearings. The tavern is public-rule: behind the bar and the cellar are off-limits. Houses are private. The merchant's study and the watch armoury are personal or professional. *Sources: Andersen (§5); Thief's public and private (§2).*

21. **Plausibility.** Every room has a real function players can reason from: kitchen, cellar, loft, counting room, sacristy. Every watchman has a sensible way to his post, and buildings must look able to stand. *Sources: Smith's plausibility test (§4); the Clockwork Mansion's functional rooms (§3); Hitman's walls (§5); Stuart's pseudo-natural levels (§7).*

22. **Facades are bigger than interiors; say so honestly.** Upper floors you can't enter should read as shuttered, barred or bricked. Never use a door that looks openable but isn't. *Sources: Colantonio and the bricked Hound Pits floor (§4); fake doors in Life of the Party and fan missions (§2, §7).*

23. **One house kit on one grid.** Set doorframe, window and mantle metrics first. Use footprints in multiples, for example 4 m plots and 2 m bays, with a separate stair "shaft" sub-kit [ours: the sizes]. Give each house one quirk. Vary clutter more than architecture, and each quarter's azulejo and stone. *Sources: Burgess and Purkeypile (§8.3); Prague's three architectural areas (§6); `iberian.md` on one stone per district.*

24. **Side content sits on the main path.** At least one side job lies across the route to the upper gate, for example a drunk in the tavern door who wants his debt note back from the merchant. At least one job pays out a route. *Sources: Golden Ticket (§6); Slackjaw (§4); Painter's Wife's linked side story (§7).*

25. **Signal, don't nag; accept unseen content; test with nothing.** Use affordances (broken railings, lit key doors, sound cues), not nagging lines. Accept that players will miss whole houses; that is what makes them compare routes. Play every key building with no consumables before calling it done. *Sources: the "go upstairs" nag (§4); Carrier's coffee machine talks and no-powers play (§3); Jimmy Lu's study of affordances (§3); Smith on the balance of help (§8.1).*

---

## Sources

**§1 Thief: Deadly Shadows**
- https://en.wikipedia.org/wiki/Thief:_Deadly_Shadows
- https://www.pcgamer.com/ion-storm-austins-journey-from-thief-to-thief-by-way-of-deus-ex/
- https://thief.fandom.com/wiki/Mapping_the_City
- https://thiefseries.fandom.com/wiki/Mapping_the_City
- https://thief.fandom.com/wiki/Old_Quarter
- http://pc.gamespy.com/pc/thief-deadly-shadows/guide/page_17.html
- https://techraptor.net/gaming/guides/better-with-age-thief-deadly-shadows-15-years-later
- https://www.pcgamesn.com/thief-deadly-shadows/modder-snatches-away-thief-deadly-shadows-loading-screens
- https://slashdot.org/story/06/06/15/1919203/the-downfall-of-the-thief-series
- https://gamefabrique.com/games/thief-deadly-shadows/
- https://metacouncil.com/threads/thief-3-deadly-shadows-is-a-good-game-thats-even-better-with-mods.1276/
- https://gamingpastime.com/thief-deadly-shadows-pc-review/
- https://gameinformer.com/b/features/archive/2014/04/07/afterwords-thief

**§2 Thief Gold and Thief II**
- https://book.leveldesignbook.com/studies/sp/assassins
- https://the-spoiler.com/ACTION/Looking.glass/thief.3/thief05.htm
- http://www.digital-eel.com/zdim/stuff/TDPdesign.htm
- https://thief.fandom.com/wiki/OM_TG_Thieves%27_Guild
- https://techraptor.net/gaming/features/even-when-its-bad-its-good-defending-thieves-guild-thief
- http://www.thief-thecircle.com/guides/keeperchapel/Ambush!/
- http://alexfung.info/favorite/game.t2/t205.html
- https://www.klatremus.org/t2/Mission4.htm
- https://www.ttlg.com/forums/showthread.php?t=41604
- https://gropingtheelephant.com/blog/?p=2771
- https://gropingtheelephant.com/blog/?p=3100
- https://gropingtheelephant.com/blog/?p=3776
- https://gropingtheelephant.com/blog/?p=204
- https://joncheetham.medium.com/the-almost-perfect-level-design-of-thief-ii-the-metal-age-c3bacee98e0d
- https://andrewyoderdesign.blog/2015/09/11/on-thiefs-level-design-maps-and-territories/
- https://www.gamedeveloper.com/design/thief-tense-narrative-through-level-design-and-mechanics
- https://www.thiefguild.com/topics/106718/a-stupendous-map

**§3 Dishonored 2**
- https://www.gamesradar.com/dishonored-2s-level-designer-explains-how-to-build-the-perfect-level/
- https://www.criticalhit.net/gaming/dishonored-2-has-a-layered-and-deeper-approach-to-level-design/
- https://www.eurogamer.net/dishonored-2s-approach-to-level-design
- https://www.eurogamer.net/how-dishonored-2-hides-its-best-details-in-the-periphery
- https://www.gamedeveloper.com/design/level-design-deep-dive-i-dishonored-2-s-i-clockwork-mansion
- https://www.pcgamer.com/balancing-art-direction-and-level-design-in-dishonored-2/
- https://www.pcgamer.com/dishonored-2-concept-gallery-with-insights-from-arkanes-art-director/
- https://www.inverse.com/gaming/23269-dishonored-2-sebastien-mitton-art-director-arkane-studios-interview
- https://www.acmi.net.au/works/100859--set-design-in-dishonored-2/
- https://80.lv/articles/modular-design-in-dishonored-2
- https://designingsound.org/2017/02/22/dishonored-2-interview/
- https://www.gamebanshee.com/news/117972-inside-the-epic-themed-missions-of-dishonored-2.html
- https://bethesda.net/en-US/news/dishonored-2-howlers-vs-overseers
- https://jimmylu.net/dishonored-level-project/
- https://www.polygon.com/2016/12/2/13817994/edge-of-the-world-walkthrough-stealth/
- https://www.polygon.com/2016/12/2/13818014/the-good-doctor-walkthrough-stealth/
- https://www.neoseeker.com/dishonored-2/walkthrough/The_Royal_Conservatory
- https://kotaku.com/what-made-dishonored-2s-time-travel-level-so-good-1819596566

**§4 Dishonored**
- https://www.pcgamer.com/the-making-of-dishonoreds-greatest-mission-lady-boyles-last-party/
- https://www.dualshockers.com/making-of-dishonored-harvey-smith-raph-colantonio/
- https://www.gamedeveloper.com/design/-i-dishonored-i-s-harvey-smith-player-choice-is-paramount-in-design
- https://kotaku.com/dishonoreds-party-level-rewrote-the-rules-of-stealth-ga-1613011624
- https://web.archive.org/web/20200607215321/https:/www.eurogamer.net/articles/2012-11-07-peeling-back-the-layers-of-dishonored-with-harvey-smith-and-raph-colantonio
- https://gameranx.com/updates/id/7640/article/bethesda-shows-two-ways-to-play-dishonored-in-this-golden-cat-walkthrough/
- https://www.gamepressure.com/dishonored/infiltrating-the-golden-cat-club/z041b9
- https://dishonored.fandom.com/wiki/House_of_Pleasure
- https://www.gamedeveloper.com/design/postmortem-the-level-design-of-dishonored-series

**§5 Hitman**
- https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/
- https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/2/
- https://en.wikipedia.org/wiki/Sapienza_(Hitman)
- https://en.wikipedia.org/wiki/Hitman_(2016_video_game)
- https://www.gamedeveloper.com/design/-i-hitman-i-dev-says-the-secret-to-expansive-level-design-is-spirals
- https://www.rockpapershotgun.com/how-hitmans-hokkaido-level-was-made
- https://www.pcgamesn.com/hitman/hitman-hokkaido-sapienza-design-interview
- https://www.pcgamer.com/how-the-creators-of-hitman-use-social-science-to-design-perfect-murder-playgrounds/
- https://www.ibtimes.co.uk/hitmans-game-director-season-finale-japan-sapienza-his-favourite-kill-season-1589102
- https://www.hitmanforum.com/t/does-anyone-know-how-many-npcs-are-in-the-h3-maps/7009?page=2
- https://www.ludo.guide/guide/hitman-world-of-assassination/hitman-world-of-assassination-part-87
- https://www.gamereactor.eu/hitman-sapienza-preview/
- https://www.gamereactor.eu/reflecting-on-hitman-season-one-with-io-interactive/
- https://blog.playstation.com/2016/05/25/hitman-episode-3-marrakesh-launches-may-31/

**§6 Deus Ex**
- https://www.gamedeveloper.com/design/postmortem-ion-storm-s-i-deus-ex-i-
- https://deusex.fandom.com/wiki/Hell%27s_Kitchen
- https://www.worthplaying.com/article/2011/8/11/previews/82797-deus-ex-human-revolution-all-a-day-at-eidos-montreal-update-5/
- https://www.gamebanshee.com/news/115167-deus-ex-human-revolution-level-design-blog-part-two.html
- https://xandermarkham.blogspot.com/2011/07/future-shock-deus-ex-human-revolution_28.html
- https://www.gamedeveloper.com/design/level-design-lessons-learned-building-i-deus-ex-mankind-divided-i-s-prague
- https://gdcvault.com/play/1024003/A-City-of-a-Thousand
- https://www.gamedeveloper.com/design/video-making-exploration-rewarding-in-i-deus-ex-mankind-divided-i-
- https://80.lv/articles/deus-ex-mankind-divided-building-prague-city-hub
- https://www.pcgamer.com/taking-on-the-slums-with-new-augs-in-deus-ex-mankind-divided/2/
- https://www.pcgamer.com/deus-ex-mankind-divided-power-and-choice-in-cyberpunk-prague/

**§7 The Dark Mod and fan campaigns**
- https://wiki.thedarkmod.com/index.php?title=Fan_Missions_for_The_Dark_Mod
- https://wiki.thedarkmod.com/index.php?title=Volta_III%3A_Gemcutter_%28FM%29
- https://www.moddb.com/mods/the-dark-mod/news/happy-holidays-from-the-dark-mod
- https://www.klatremus.org/TDM_PaintersWife.htm
- https://www.thiefguild.com/topics/106718/a-stupendous-map
- https://www.thiefguild.com/topics/75034/be-prepared
- https://oldpcgaming.net/thief-the-dark-mod-review/
- https://reload-magazine.net/articles/thief-the-black-parade-mar-2025
- https://tvtropes.org/pmwiki/review_comments.php?id=22891
- https://backloggd.com/u/PerrySimm/review/2370494/
- https://pjamesstuart.substack.com/p/thief-and-butterfingered-infinity

**§8 Level-design writing**
- https://www.gdcvault.com/play/1013435/Level-Building-for-Stealth
- https://www.slideserve.com/libitha/level-building-for-stealth-gameplay-powerpoint-ppt-presentation
- https://www.youtube.com/watch?v=XrUNCn8OxcY
- https://www.scribd.com/presentation/720268810/RandySmith-GDC-2002
- https://book.leveldesignbook.com/culture/unfinished-pages/history-encounter-design
- https://www.gamedeveloper.com/design/examining-the-essential-building-blocks-of-stealth-play
- https://www.gamedeveloper.com/design/designing-better-levels-through-human-survival-instincts
- https://www.routledge.com/Architectural-Approach-to-Level-Design-Second-edition/Totten/p/book/9780815361367
- http://blog.joelburgess.com/2013/04/skyrims-modular-level-design-gdc-2013.html
- https://www.slideshare.net/slideshow/gdc2013-kit-buildingfinal/17728576
- https://t-machine.org/index.php/2013/05/04/skyrim-level-design-transcript-notes-from-gdc-2013-talk/
- https://www.worch.com/2010/03/11/gdc-2010/
- https://www.slideserve.com/zahur/what-happened-here-environmental-storytelling

**Not found:**
- Steve Lee's or Pagliarulo's Thief design essays. Only Pagliarulo's 2000 TTLG post was found.
- District sizes in metres for the TDS City, Karnaca or Sapienza.
- Guard counts for Dishonored 2 missions.
- Dinga Bakaba's talks on Karnaca's districts.
- Layout specifics of A New Job, Lords & Legacy and A House of Locked Secrets.
