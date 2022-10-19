#!/usr/bin/env bash
set -euox pipefail

DATA_DIR="./data"
GPX_DIR="./docs/gpx"
DOWNLOAD_JSON=${1:-FALSE}


mkdir -p "$GPX_DIR"
mkdir -p "$DATA_DIR"


function escape_query(){
    query="$1"
    python3 -c 'import sys;import urllib.parse;  print("&".join([x.split("=",1)[0] + "=" + urllib.parse.quote_plus(x.split("=",1)[1]) for x in sys.stdin.read().split("&")]));' <<< "$query"
}

function convert_to_gpx(){
    slug="$1"
    pad_path="${GPX_DIR}/${slug}.gpx"
    rm -f "$pad_path"
    ogr2ogr -f GPX "$pad_path" "${DATA_DIR}/linestring.geojson" -dialect sqlite -sql \
    "SELECT 
        ST_Union(geom) as geom,
        round(ST_Length(st_transform(ST_Union(geom), 28992))/1000,2) as lengte,
        max(padnummer) as padnummer,
        coalesce(null,naam) as naam,
        coalesce(null,slug) as slug,
        substr(substr(group_concat(url), instr(group_concat(url), 'https://')), 1, instr(substr(group_concat(url), instr(group_concat(url), 'https://')), '\"')-1) as url
    FROM (
		SELECT 
            geometry as geom, 
            NAAM as naam,
            slug,
            NULLIF(PADNUMMER, 0) as padnummer,
            ULR as url
        FROM linestring
	) AS linestring_proc 
    WHERE slug='${slug}'" \
    -s_srs "EPSG:3857" -t_srs "EPSG:4326" -nlt MULTILINESTRING -nln "${slug}" -dsco GPX_USE_EXTENSIONS=YES -lco  FORCE_GPX_TRACK=YES
}

function get_att(){
    att_name="$1"
    file_path="$2"
    layer_name="$3"
    if ogrinfo "$file_path" "$layer_name" -so | grep "${att_name}:" > /dev/null;then
        ogrinfo "$file_path" "$layer_name"  | grep "$att_name" | grep "=" | cut -d= -f2 | xargs
    fi
    echo ""
}

### DOWNLOAD KLOMPENPADEN FROM ARCGIS WEBSERVICE

BASE_URL="https://services1.arcgis.com/onNgFGfh3zOPcUU0/arcgis/rest/services/Klompenpaden_webkaart_2/FeatureServer"
# shellcheck disable=SC2089
query_linestring='f=geojson&where=1=1&returnGeometry=true&spatialRel=esriSpatialRelIntersects&maxAllowableOffset=1.0583354500042348&outFields=*&maxRecordCountFactor=2&outSR=3857&resultOffset=0&resultRecordCount=4000&cacheHint=true&quantizationParameters={"mode":"view","originPosition":"upperLeft","tolerance":1.0583354500042348,"extent":{"xmin":118766.25439999998,"ymin":416947.87249999866,"xmax":248800.14389999956,"ymax":500138.99170000106,"spatialReference":{"wkid":28992,"latestWkid":28992}}}'
query_linestring_esc=$(escape_query "$query_linestring")

linestring_svc_url="${BASE_URL}/0/query"
linestring_url="${linestring_svc_url}?${query_linestring_esc}"

if [[ $DOWNLOAD_JSON == "TRUE" ]];then
    wget "$linestring_url" -O "${DATA_DIR}/linestring.geojson"
fi

query_point='f=geojson&where=1=1&returnGeometry=true&spatialRel=esriSpatialRelIntersects&outFields=*&maxRecordCountFactor=4&outSR=3857&resultOffset=0&resultRecordCount=8000&cacheHint=true&quantizationParameters={"mode":"view","originPosition":"upperLeft","tolerance":1.0583354500042348,"extent":{"xmin":119362.09730000047,"ymin":417161.27499999845,"xmax":248796.27969999984,"ymax":499014.62900000066,"spatialReference":{"wkid":28992,"latestWkid":28992}}}'
query_point_esc=$(escape_query "$query_point")

point_svc_url="${BASE_URL}/1/query"
point_url="${point_svc_url}?${query_point_esc}"
if [[ $DOWNLOAD_JSON == "TRUE" ]];then
    wget "$point_url" -O "${DATA_DIR}/point.geojson"
fi

### ADD SLUG ATTRIBUTE TO LINESTRING

python3 -c \
'from slugify import slugify
import json

with open("data/linestring.geojson", "r") as f:
    geojson = json.load(f)
    for ft in geojson["features"]:
        ft["properties"].update({"slug": slugify(ft["properties"]["NAAM"])})

with open("data/linestring.geojson", "w") as f:
    json.dump(geojson, f)'


### CONVERT KLOMPENPADEN TO INDIVIDUAL GPX FILES

slugs=$(ogrinfo data/linestring.geojson -sql "select slug from linestring" -geom=NO | grep "slug" | grep "=" | cut -d= -f2  | sort -u)
while read -r slug; do 
    convert_to_gpx "$slug"
done <<<"$slugs"


### CONVERT GPX FILES TO JSON INDEX

csv="pad_url;pad_naam;pad_slug;pad_lengte;pad_pdf_url\n"
set +u
for gpx_file in $GPX_DIR/*.gpx; do
    pad_url=$(get_att ogr_url "$gpx_file" "tracks")
    pad_naam=$(get_att ogr_naam "$gpx_file" "tracks")
    pad_slug=$(get_att ogr_slug "$gpx_file" "tracks")
    pad_lengte=$(get_att ogr_lengte "$gpx_file" "tracks")
    pad_pdf_url=""
    if [[ -n $pad_url ]];then        
        html_path="./html/$(basename "$gpx_file" .gpx).html"
        if [[ ! -f "$html_path" ]];then
            curl -L "$pad_url" -o "$html_path"
        fi
        if pup < "$html_path" 'a attr{href}' | grep "pdf" > /dev/null;then
            pad_pdf_url=$(pup < "$html_path" 'a attr{href}' | grep "pdf" | head -n1 | xargs | tr -d '\n')
        elif pup < "$html_path" 'a attr{href}' | grep "https://bit.ly" > /dev/null;then
            pad_pdf_url=$(pup < "$html_path" 'a attr{href}' | grep "https://bit.ly" | head -n1 | xargs | tr -d '\n')
        fi
    fi
    csv="${csv}${pad_url};${pad_naam};${pad_slug};${pad_lengte};${pad_pdf_url}\n"
done
set -u

echo -e "$csv" > data/klompenpaden.csv
jq -R -s -f scripts/csv2json.jq data/klompenpaden.csv > data/klompenpaden.json

python3 -c \
'import json
import datetime
with open("data/klompenpaden.json","r") as json_file_r:
    values = json.load(json_file_r)
    today = datetime.date.today()
    count = len(values)
    values = {
        "klompenpaden": values,
        "count": count
    }
    values.update({"updated": str(datetime.datetime.now()).rsplit(":", 1)[0]})
with open("data/klompenpaden.json","w") as json_file_w:
    json.dump(values, json_file_w)
'

### GENERATE INDEX GEOJSON FILE

output_file=docs/index.geojson
rm -f "$output_file"
for gpx_file in $GPX_DIR/*.gpx; do
    append_flag=""
    if [[ -f $output_file ]];then
        append_flag="-append"
    fi
    ogr2ogr $append_flag -f GeoJSON "$output_file" "$gpx_file" -dialect sqlite -sql \
    "select st_centroid(geometry) as geom,ogr_naam as naam,ogr_slug as slug from tracks" -nln overview_points
done
