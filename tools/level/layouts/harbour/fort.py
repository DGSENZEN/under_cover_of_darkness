"""The fort at the harbour's mouth (after Lisbon's Torre de Belem): its
bastion in the sea at the end of the rocky spit, its tower, domed garitas
hung from the bastion's corners."""

from . import FORT

BASTION_TOP = 4.0


def lay(L):
    x, z = FORT
    L.put("fort_bastion", (x, 0.0, z), 0.0, "fort")
    L.put("fort_tower", (x, BASTION_TOP, z - 4.0), 0.0, "fort")

    for dx, dz in ((-6.0, 12.3), (6.0, 12.3), (-15.3, 4.0), (15.3, 4.0)):
        L.put("turret_domed", (x + dx, BASTION_TOP - 0.6, z + dz), 0.0, "fort")
