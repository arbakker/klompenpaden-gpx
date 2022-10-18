#!/usr/bin/env python3

import pystache
from slugify import slugify
import datetime
import json
with open("index.html.template","r") as template, open("data/klompenpaden.json","r") as json_file:
    values = json.load(json_file)
    today = datetime.date.today()
    values.update({"updated": str(datetime.datetime.now()).rsplit(":",1)[0]})
    for item in values["klompenpaden"]:
        item.update( {"slug": slugify(item["pad_naam"])})
        item.update( {"gpx": "gpx/" +  slugify(item["pad_naam"])+".gpx"})
    print(pystache.render(template.read(), values))
