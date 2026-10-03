"""The job's words (data/jobs/<district>.job, scripts/Level/JobBook.gd) as the
level pipeline needs them: which readable slots a district's file has, so a
level's readable markers can be checked against it (rules.readable_problems).
"""

import os
import re

JOBS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "jobs")
HEADER = re.compile(r"^==\s*readable\s+([A-Za-z0-9_]+)\s*$")


def readable_slots(district, folder=JOBS):
    """Return the set of readable ids in `folder`/<district>.job (empty if no file)."""
    path = os.path.join(folder, "%s.job" % district)

    if not os.path.exists(path):
        return set()

    with open(path) as f:
        return {m.group(1) for m in (HEADER.match(line.strip()) for line in f) if m}
