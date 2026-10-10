"""What made the Zócalo the way it is, as fields over the map (the spec's
section 4): the lakebed swallowing the cathedral and Santo Domingo; the
canal come back and the old flood; the Eclipse's future seeping in round the
station, the palace's bureaucracy and the deco tower; the wear of the
market, the ring and Madero."""


def lay(P):
    P.event("subsidence", centre=(-32, -205), radius=150, strength=0.9)
    P.event("subsidence", centre=(-170, -250), radius=90, strength=0.6)
    P.event("subsidence", line=[(-310, 173), (310, 173)], reach=50, strength=0.4)
    P.event("water", line=[(-310, 173), (310, 173)], reach=40, strength=1.0)
    P.event("water", centre=(0, 240), radius=100, strength=0.4)
    P.event("seepage", centre=(0, 0), radius=90, strength=1.0)
    P.event("seepage", centre=(160, 0), radius=100, strength=0.9)
    P.event("seepage", centre=(105, -185), radius=60, strength=0.8)
    P.event("use", centre=(0, 240), radius=150, strength=0.9)
    P.event("use", line=[(-110, -120), (110, -120), (110, 120), (-110, 120), (-110, -120)], reach=30, strength=0.6)
    P.event("use", line=[(-310, -117), (-120, -117)], reach=25, strength=0.7)
    P.event("use", centre=(-170, -250), radius=60, strength=0.6)
