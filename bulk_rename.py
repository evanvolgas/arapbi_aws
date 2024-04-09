import os

for filename in os.listdir("."):
    f = filename.split(".")[0]
    os.mkdir(f"dt={f}")
    os.rename(filename, f"dt={f}/{filename}")
