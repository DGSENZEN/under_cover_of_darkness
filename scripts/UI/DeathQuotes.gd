extends RefCounted
## What is on the screen when you die: the user's choice of words, quoted as the user gave them, and
## which of them each way of going may draw. A death draws at random among its own, never the
## one it showed last time.

const ALL := [
	{"text": "“Los muertos pesan más que los vivos; lo aplastan a uno.”", "by": "Juan Rulfo, Pedro Páramo"},
	{"text": "“Cada suspiro es como un sorbo de vida del que uno se deshace.”", "by": "Juan Rulfo, Pedro Páramo"},
	{"text": "“No hay paz ni cierre. No hay reconciliación. No hay cruce. Todo eso es ficción.”", "by": "Mariana Enriquez, Mis Tristes Muertos"},
	{"text": "“Nos asustan los fantasmas y sin embargo vivimos minuciosamente entre ellos.”", "by": "Silvina Ocampo, La Torre de los Caballos Azules"},
	{"text": "“Cualquier acto que ejecutemos puede ser el último; no hay rostro que no esté a punto de desdibujarse como el rostro de un sueño.”", "by": "Jorge Luis Borges, El Aleph."},
	{"text": "“¿Y qué es la vida sino una sombra que pasa?”", "by": "Rosario Castellanos, Balún Canán"},
	{"text": "“Era un fantasma que no sabía que estaba muerto, y eso era lo peor.”", "by": "Roberto Bolaño, Los sinsabores del verdadero policía"},
	{"text": "“Los muertos no se van; se quedan pegados a las paredes, a los muebles, a la ropa.”", "by": "Laura Restrepo, Delirio."},
]

## By index in ALL. The weight of the dead and the sip of life for what drinks you; ghosts that watch
## and faces coming apart for the eyes; no peace for both; the last act for a blow.
const FOR := {
	&"animas": [1, 0, 7],
	&"mouth": [1, 0, 7],
	&"eyes": [3, 4, 2],
	&"both": [2, 0, 6, 7],
	&"swipe": [4, 5, 1],
	&"fall": [5, 4, 2, 6],
}

static var _last := -1


static func choose(kind: StringName) -> Dictionary:
	var these: Array = FOR.get(kind, FOR[&"fall"])
	var pick: int = these[randi() % these.size()]

	if pick == _last:
		pick = these[(these.find(pick) + 1) % these.size()]

	_last = pick
	return ALL[pick]
