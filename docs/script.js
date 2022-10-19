import * as ol from "https://esm.run/ol";
import * as layer from "https://esm.run/ol/layer";
import * as source from "https://esm.run/ol/source";
import * as format from "https://esm.run/ol/format";
import * as style from "https://esm.run/ol/style";

const symbolColor = "orange";
const styles = {
  Point: new style.Style({
    image: new style.Circle({
      fill: new style.Fill({
        color: symbolColor,
      }),
      radius: 5,
      stroke: new style.Stroke({
        color: "#ffffff",
        width: 2,
      }),
    }),
  }),
  LineString: new style.Style({
    stroke: new style.Stroke({
      color: symbolColor,
      lineDash: [2, 6, 6],
      width: 3,
    }),
  }),
  MultiLineString: new style.Style({
    stroke: new style.Stroke({
      color: symbolColor,
      lineDash: [2, 6, 6],
      lineCap: "square",
      width: 3,
    }),
  }),
  Label: new style.Style({
    text: new style.Text({
      offsetX: 12,
      offsetY: -12,
      textAlign: "left",
      font: "small-caps bold  13px NS Sans,Segoe UI,Myriad,Verdana,sans-serif",
      overflow: false,
      fill: new style.Fill({
        color: "#000",
      }),
      stroke: new style.Stroke({
        color: "#fff",
        width: 3,
      }),
    }),
  }),
};
function labelStyleFunction(feature, resolution) {
  styles.Label.getText().setText(feature.get("naam"));
  return [styles[feature.getGeometry().getType()], styles.Label];
}
function styleFunction(feature, resolution) {
  if (resolution < 50) {
    return labelStyleFunction(feature, resolution);
  }
  return [styles[feature.getGeometry().getType()]];
}

fetch("./index.geojson")
  .then((response) => response.json())
  .then((data) => {
    const vectorSource = new source.Vector({
      features: new format.GeoJSON().readFeatures(data, {
        dataProjection: "EPSG:4326",
        featureProjection: "EPSG:3857",
      }),
    });
    const vectorLayer = new layer.Vector({
      source: vectorSource,
      style: styleFunction,
    });
    const map = new ol.Map({
      layers: [
        new layer.Tile({
          className: "bw basemapLayer",
          source: new source.OSM(),
        }),
        vectorLayer,
      ],
      target: "map",
      view: new ol.View({
        center: [653995.214, 6810539.2202],
        zoom: 9,
      }),
    });
    map.on("singleclick", (evt) => {
      const fts = map.getFeaturesAtPixel(evt.pixel);
      const ft = fts.length > 0 ? fts[0] : null;
      if (ft) {
        const props = ft.getProperties();
        const slug = props.slug;
        window.location.href = `./#${slug}`;
      }
    });
  });
