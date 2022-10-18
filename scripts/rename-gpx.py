#!/usr/bin/env python3
import pystache
from slugify import slugify
import datetime
import json

import os

base_dir="gh-pages/gpx"
directory = os.fsencode(base_dir)
    
for file in os.listdir(directory):
    filename = os.fsdecode(file)
    new_filename = slugify(filename.split(".")[0])
    new_filename = f"{new_filename}.gpx"
    os.rename(os.path.join(base_dir, filename), os.path.join(base_dir, new_filename))
# with open("index.html.template","r") as template, open("klompenpaden.json","r") as json_file:
#     values = json.load(json_file)
#     today = datetime.date.today()
#     values.update({"updated": str(datetime.datetime.now()).rsplit(":", 0)})
#     for item in values["klompenpaden"]:
#         item.update( {"slug": slugify(item["pad_naam"])})
#         item.update( {"gpx": "gpx/" + item["pad_naam"].lower()+".gpx"})
#     print(pystache.render(template.read(), values))
