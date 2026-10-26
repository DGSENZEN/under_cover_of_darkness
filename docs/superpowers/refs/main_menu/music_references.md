# Main menu music: references

Song: D minor, ~74-78 bpm, Studio Grand piano plus Logic Drummer (Mixed Boom Bap). Goal: neo-noir / trip hop / occult with bolero, danzón and son colour. Four live-mixed stems in game. Each button plays an in-key jingle from its own stem: New Game = muted trumpet, Continue = nylon/requinto, Settings = Rhodes/vibes, Lore = bells/choir. Researched 25 Oct 2026. "Unconfirmed" means I looked and found nothing.

## 1. Deadlock: Hideout, title, match start

- **Four stems, mixed live:** Base, FX, Low and High, played from the Play Terminal. Getting closer raises volume and intensity. FX peaks when you face the terminal. With the terminal menu open, Low comes forward, Base and FX drop back and High is muted. Going idle fades to a floor. ([Hideout/Music](https://deadlock.wiki/Hideout/Music))
- **Tempo:** the loops are named `music_hideout_play_base_lp_155bpm`, `..._high_lp_155bpm`. That is **77.5 bpm in half-time**, inside our range. ([base](https://deadlock.wiki/File:Music_hideout_play_base_lp_155bpm.mp3), [high](https://deadlock.wiki/File:Music_hideout_play_high_lp_155bpm.mp3))
- **Title to Hideout:** the title screen has its own track. On leaving it, a ~5 s "build" cue leads into the loop. When you queue, a Start cue plays once, then a Wait loop replaces the ambient track. ([Music](https://deadlock.wiki/Music), [build](https://deadlock.wiki/File:Music_hideout_build_155bpm.mp3))
- **Match start:** "Connecting to Match" loops from one of eight random start points. Patron Introduction and per-round Round Start stingers follow. Killstreak stingers raise the guitar and choir pitch. ([Music](https://deadlock.wiki/Music))
- **Style and composer:** trip hop identity since the Six New Heroes update. The composer is an anonymous developer, and Morasky [denied writing it](https://x.com/MikeMorasky/status/1849222739900657787). ([Music](https://deadlock.wiki/Music))
- **Unconfirmed:**
  - whether UI hover/select sounds are pitched or quantized to the score
  - any hero-select music behaviour
  - what instruments are in each stem, and the key
  - any dev talk or Reddit/YouTube analysis of the system

**Apply:** four equal-length 76 bpm loops in the `AudioStreamSynchronized` that `scripts/Audio/Music.gd` already uses. Base = piano + drums, Low = bass/drone, High = lead, FX = texture. Hovering a button lifts its stem. Settings copies Deadlock's menu-open mix (drop High, keep Low). Idle fades to Base. A one-bar "build" cue plays on leaving the title.

## 2. UI sounds that follow the music

- **Rez:** fire and lock-on sounds snap to the beat. Frequent sounds work like hi-hats, and big crashes stay rare. ([Game Developer](https://www.gamedeveloper.com/design/planckogenesis-part-i-quantizing-events)) Mizuguchi called quantization the key discovery and carried it into Lumines and Child of Eden. ([oral history](https://gamedeveloper.com/audio/oral-history-of-i-rez-i-recounts-a-marriage-of-game-and-music))
- **Wind Waker / Mario Galaxy:** Wind Waker's sword hits ring in time with the battle music. In Galaxy, the team ducked sparkly parts of the music so the Star Bit sound had room. ([Iwata Asks](https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-Super-Mario-Galaxy/Volume-3-The-Sound-Team/4-Sound-Effects-You-Can-Feel/4-Sound-Effects-You-Can-Feel-205134.html)) A search summary says Galaxy synced MIDI data to the streamed music to time effects. I couldn't open [the page](https://iwataasks.nintendo.com/interviews/wii/super_mario_galaxy/2/0) to check.
- **Super Mario Odyssey:** the power-line sound changes to fit the new tune when the music changes ([Vice](https://creators.vice.com/en/article/xwvyan/the-tiny-touches-of-super-mario-odyssey-extend-to-even-the-sound-effects-harmonize-music-easter-egg), from the search summary; the page didn't load). The pause-menu chimes can play a Galaxy melody. ([WhatCulture](https://whatculture.com/gaming/10-video-game-pause-screen-secrets-you-totally-missed))
- **How it is done:**
  - **Wwise, chords:** music cues set a chord State Group, and each UI sound is a Switch Container with one variant per chord. ([Audiokinetic Q&A](https://blog.audiokinetic.com/qa/10334/harmonising-ui-sounds-according-to-music))
  - **Wwise, timing:** next-beat stingers work but can't be cut off and retriggered. The alternative is to queue the sound on `AK_MusicSyncBeat`/`Bar` callbacks. ([Q&A](https://audiokinetic.com/qa/6995/music-synchronization-and-callbacks-with-posttrigger), [Tetris Beat](https://audiokinetic.com/fr/blog/playing-an-iconic-puzzle-game-to-the-beat))
  - **FMOD:** there is a "Delay & Quantization" trigger behaviour. ([docs](https://fmod.com/docs/2.03/studio/instrument-reference.html); the page didn't render, so the options are unconfirmed)
  - **Godot 4.3+** ([release](https://godotengine.org/releases/4.3/)): `AudioStreamInteractive` switches clips on the next beat or bar ([docs](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html)). `AudioStreamSynchronized` runs up to 32 locked streams, each with its own volume ([docs](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html)). There is no beat signal, so derive it from `get_playback_position()`.
- **The catch:** UI sounds that wait for the beat feel laggy. ([GameDev.net](https://gamedev.net/blogs/entry/2249715-beat-syncing))

**Apply:** hover plays a quiet chord tone at once. Press plays the stem's phrase on the next eighth note (0.39 s at 76 bpm), never the next bar. Write two or three chord variants of each jingle and pick the one that matches the bar.

## 3. Trip hop production

- **Tempo:** *Teardrop* reads as 77 bpm, D minor. That is one unverified DJ-library reading, but it matches our song almost exactly. ([listing](https://cs.uwaterloo.ca/~dtompkin/music/track/MASSATCK_MEZ/MASSATCK_MEZ-03.html))
- **Portishead, *Dummy*:** they cut their own drumming (Clive Deamer) to vinyl, scuffed and scratched it, then resampled it. They also recorded through a broken amp. Barrow plays Rhodes, Utley plays theremin on *Mysterons*, and they drew on spy films and John Barry. *Sour Times* samples Lalo Schifrin, and *Glory Box* samples Isaac Hayes. ([Wikipedia](https://en.wikipedia.org/wiki/Dummy_(album)), [UAL blog](https://creativemixing.myblog.arts.ac.uk/?p=27))
- **Massive Attack, *Teardrop*:** Kurzweil harpsichord. The piano's low notes are doubled in octaves through a Leslie. A drum loop runs with a double-time copy through the MPC60's delay. Moog Prodigy bass, a sampled Hammond stab and a JV-1080 choir. ([Sound on Sound](https://www.soundonsound.com/techniques/how-got-sound-neil-davidge))
- **Tricky:** *Hell Is Round the Corner* uses the same Hayes sample as *Glory Box*. ([Songfacts](https://www.songfacts.com/facts/portishead/glory-box)) **DJ Shadow**, *Endtroducing.....*: MPC60 MkII, a turntable, an ADAT, almost all samples. ([Wikipedia](https://en.wikipedia.org/wiki/Endtroducing.....))
- **Swing (Roger Linn):** 50% is straight and 66% is triplet. 54% loosens straight 16ths. At 90 bpm, 62% feels looser than 66%. ([Attack](https://attackmagazine.com/features/interview/roger-linn-swing-groove-magic-mpc-timing/2))
- **Logic:**
  - Drummer's Details view has a Swing control. ([Apple](https://help.apple.com/logicpro/mac/10.4/en.lproj/lgcp898c7532.html))
  - Phat FX lo-fi chain: distortion, then compression, then low-pass, with Tape Delay "Ultra Dub" after. ([MusicTech](https://musictech.com/tutorials/get-a-lo-fi-sound-using-phat-fx/))
  - ChromaGlow does tube/tape saturation, Remix FX does vinyl scratches and stops, and Quick Sampler's Slice mode chops loops. ([Apple](https://www.apple.com/logic-pro/plugins-and-sounds))
  - I found no built-in vinyl-crackle plugin.

**Apply:** do the Portishead move inside the DAW. Bounce the Drummer region, run it through ChromaGlow (tape) and then Phat FX, re-slice it in Quick Sampler, and replay it at 58-62% swing, pitched down a little. Put the piano's low octave through a rotary on the Low stem.

## 4. Neo-noir jazz

- **Harmon mute:** playing it with the stem removed was Miles Davis's sound from 1946. ([Wikipedia](https://en.wikipedia.org/wiki/Mute_(music))) On *Ascenseur pour l'échafaud* (1958), his band improvised to projected film loops from a few chord sequences. ([Goldsmiths](https://research.gold.ac.uk/id/eprint/7789))
- **Goldsmith's *Chinatown*:** strings, four pianos, four harps, two percussionists, one trumpet (Uan Rasey), plus a **güiro**. He deliberately avoided period pastiche. ([MFiles](https://w.mfiles.co.uk/reviews/jerry-goldsmith-chinatown.htm))
- **Bohren & der Club of Gore:** Rhodes, Mellotron, tenor sax, double bass, brushes, played extremely slowly. Start with *Black Earth*. ([PopMatters](https://popmatters.com/bohrenandderclubofgore-black-2495842249.html))
- **Badalamenti, *Fire Walk With Me*:** Ron Carter on bass, plus vibraphone, trumpet and tenor sax, with a somber trumpet over synth strings. ([MusicBrainz](https://musicbrainz.org/release/75aef50f-ec8f-4dcd-ac8c-42de9c35bb4e), [HorrorDNA](https://www.horrordna.com/music/twin-peaks-fire-walk-with-me-original-motion-picture-soundtrack-angelo-badalamenti-music-review))
- ***Grim Fandango* (McConnell):** Schafer gave him Bogart films and raw Mexican **son** records. His other models were Ellington and the *Casablanca* and *Sierra Madre* scores. The players, mariachi included, came from SF's Mission District. ([AudioGang](https://www.audiogang.org/?p=3146), [Wikipedia](https://en.wikipedia.org/wiki/Music_of_Grim_Fandango))
- **Harmony:** tritone substitution, diminished chords and #11 are core jazz tension devices. ([Wikipedia](https://en.wikipedia.org/wiki/Tritone))
- **Logic:**
  - Studio Horns has sustain, staccato and falls articulations. A harmon mute is unconfirmed. ([Apple](https://support.apple.com/guide/logicpro-ipad/lpip4754998b/ipados))
  - There is an Upright Bass Player Session Player. ([Apple](https://www.apple.com/logic-pro/plugins-and-sounds))

**Apply:** New Game is a stem-out harmon trumpet answering the piano, with no vibrato. Try Dm6 / Bbmaj7#11 / E7b9 (or its tritone sub Bb7) / A7b9. Brushes on Base in the verse, boom bap in the drop.

## 5. Latin jazz and Mexican-Cuban colour

- **Cinquillo:** five strokes (8th, 16th, 8th, 16th, 8th), an elaborated tresillo. Danzón and Cuban bolero are built on it. The **baqueteo** is a cinquillo plus four straight eighths, and it contains every clave stroke. ([Wikipedia](https://en.wikipedia.org/wiki/Cinquillo))
- **Tumbao:** the bass's last note is tied over the barline, so only the offbeats sound (bombo, ponche). The conga puts open tones on 2&. Piano guajeos are also called tumbaos. ([Wikipedia](https://en.wikipedia.org/wiki/Tumbao))
- **Period:**
  - Salón México opened 20 April 1920. ([La Jornada](https://www.jornada.com.mx/2017/07/29/opinion/a09o1esp))
  - Danzón arrived via Yucatán and Veracruz, played by *danzoneras*. ([Chalco](https://cultura.gobiernodechalco.gob.mx/?p=1866))
  - Lara-era boleros were on XEW radio from about 1930. ([Wikipedia](https://en.wikipedia.org/wiki/Ana_Mar%C3%ADa_Fern%C3%A1ndez))
  - The **requinto** was invented by Alfredo Gil of Los Panchos in 1944, so it is a choice for our 1920s, not period-correct. ([Wikipedia](https://en.wikipedia.org/wiki/Alfredo_Gil))
- **Fusions:**
  - **Gotan Project**, *La Revancha del Tango*: sparse synth bass and drum grooves under bandoneon. ([PopMatters](https://popmatters.com/gotanproject-revancha-2495915261.html))
  - **Nortec Collective**: sampled norteño horns and accordions in electronica. ([Remezcla](https://remezcla.com/music/nortec-collective/))
  - Lafourcade's ***Musas*** with Los Macorinos: Lara and Cantoral songs on two guitars. ([Wikipedia](https://en.wikipedia.org/wiki/Musas,_Vol._1))
  - Beltrami's ***Hellboy***: tango rhythms with choir and theremin. ([Filmtracks](https://www.filmtracks.com/titles/hellboy.html))
  - Mexican Institute of Sound and Bebel Gilberto: not researched.
- **Logic:**
  - The Percussionist **Isabela** plays a Latin kit (congas and more), with per-element variation sliders, Complexity Range and Humanize. ([Sound on Sound](https://www.soundonsound.com/techniques/perc-logic-pro-1032))
  - Bass Player follows the Chord Track. ([Synthtopia](https://www.synthtopia.com/content/2024/05/07/free-logic-pro-update-brings-new-ai-powered-features/))
  - Logic 12 (Jan 2026) added Chord ID and a Synth Player. ([Synthtopia](https://www.synthtopia.com/content/2026/01/30/apple-logic-pro-12-mainstage-4-now-available-heres-whats-new/))

**Apply:** use Goldsmith's restraint, one Latin element per stem. Play the baqueteo on güiro or claves, which reads clearly at 76 bpm against the boom bap. Tie the bass over the barline under the kick. Keep piano montuno to one two-bar fragment. Continue's jingle is a short bolero phrase in thirds.

## 6. Occult palette

- **Yamaoka (Silent Hill):** mixed dark ambient, industrial and trip hop. He cites Badalamenti and made every sound effect himself. ([Spelmusik](https://www.silenthillmemories.net/creators/interviews/2002.07.16_yamaoka_spelmusik_en.htm), [Music 4 Games](https://www.silenthillmemories.net/creators/interviews/2009.01.26_yamaoka_music4games_en.htm))
- **Lustmord:** *Heresy* (1984) is called the start of dark ambient. His sources were crypts, caves and slaughterhouses. ([5:4](https://5against4.com/2008/07/10/the-ambient-tradition-black-on-black-lustmord-and-the-dark-side-of-ambient/))
- **Demdike Stare:** named after a Pendle witch. They mix jazz, library music and industrial, and dig for horror soundtracks. ([Wikipedia](https://en.wikipedia.org/wiki/Demdike_Stare))
- **Tritone:** the "devil" label is later convention. Liszt used the interval for exactly that effect. ([Wikipedia](https://en.wikipedia.org/wiki/Tritone))
- **Logic:** Sample Alchemy resynthesises any sample, and ChromaVerb reaches 100 s decay. ([Apple](https://www.apple.com/logic-pro/plugins-and-sounds))

**Apply:** the FX stem is a D drone with a faint A-flat (tritone) that rises as the player faces the menu. Reverse the piano tails into each section. Lore's jingle is a tuned bell (D, A, then an unresolved A-flat) over a wordless Sample Alchemy choir. Record real bells and metal.
