# Code based on Polymaps example from Mike Bostock http://bl.ocks.org/899670
po = org.polymaps
map = po.map().container(d3.select("#map").append("svg:svg").node())
.zoom(13)
.center({lat: 48.455164, lon: -123.351059})# Victoria BC west of Cedar Hill Golf Course
.add(po.drag())
.add(po.wheel().smooth(false))
.add(po.dblclick())
.add(po.arrow())

# Stamen toner tiles http://maps.stamen.com
map.add(po.image().url(po.url("http://tile.stamen.com/toner/{Z}/{X}/{Y}.png")))

# Lat/Lng transform function
transform = (location) ->
  d = map.locationPoint(location)
  "translate(" + d.x + "," + d.y + ")"

createLineLayer = (routes) ->
  svgLine = d3.svg.line().x((d) => d.x).y((d) => d.y).interpolate("linear")
  line = (d) => svgLine(d.paths.map((d) => map.locationPoint(d)))
  layer = d3.select("#map svg").insert("svg:g")
  layer.selectAll("g").data(routes).enter().append("path").attr("class", "route").attr("d", (d) => line(d))
  map.on("move", -> layer.selectAll("path").attr("d", (d) => line(d)))

createBusStopLayer = (routes) ->
  # transform routes to list of bus stops
  routes.forEach (route) ->
    route.stops.map (stop) ->
      stop.route = route.route
      stop

  stops = d3.merge(routes.map (route) -> route.stops)

  # circles on map
  layer = d3.select("#map svg").insert("svg:g")
  marker = layer.selectAll("g").data(stops).enter().append("g").attr("transform", transform)
  marker.append("circle").attr("class", "stop").attr('r', 4.5)
  map.on("move", -> layer.selectAll("g").attr("transform", transform))

resultHandler = (routes) ->
  createLineLayer routes
  createBusStopLayer routes

map.add(po.compass().pan("none"))

do -> d3.json('data/uvic_transit.json', resultHandler)