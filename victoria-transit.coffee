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

# Calculates pixel for 1km distance
# http://jan.ucc.nau.edu/~cvm/latlongdist.html with 0N 0W to 0N 0.008983W is 1km
# assume you can walk 500m in 6min, this seems to be a good distance
reachableDistanceFromStop  = () ->
  pixelsPerKm = map.locationPoint({ lat: 0, lon: 0.008983 }).x - map.locationPoint({ lat: 0, lon: 0 }).x
  0.5 * pixelsPerKm

  # Lat/Lng transform function
transform = (location) ->
  d = map.locationPoint(location)
  "translate(" + d.x + "," + d.y + ")"

createBusRouteLayer = (routes, stops) ->
  # TODO prevent overplotting by intelligently selecting route segments between stops
  # map stops by their id
  stopsById = {}
  stops.forEach((stop) ->
    stopsById[stop.id] = stop
  )

  svgLine = d3.svg.line().x((d) => d.x).y((d) => d.y).interpolate("linear")
  line = (route) => svgLine(route.stops.map((routeStop) => map.locationPoint(stopsById[routeStop.point_id])))
  layer = d3.select("#map svg").insert("svg:g")
  layer.selectAll("g").data(routes).enter().append("path").attr("class", "route").attr("d", (d) => line(d))
  map.on("move", -> layer.selectAll("path").attr("d", (d) => line(d)))

createBusStopLayer = (stops) ->
    # circles on map
  layer = d3.select("#map svg").insert("svg:g")
  marker = layer.selectAll("g").data(stops).enter().append("g").attr("transform", transform)
  marker.append("circle")
  .attr("class", "stop")
  .attr('r', 4.5)
  .attr("text", (stop) => stop.routes)
  map.on("move", ->
    layer.selectAll("g").attr("transform", transform)
  )

# separate layer so it can be drawn underneath the bus stop layer
createBusStopReachLayer = (stops) ->
  layer = d3.select("#map svg").insert("svg:g")
  marker = layer.selectAll("g").data(stops).enter().append("g").attr("transform", transform)
  marker.append("circle") # reach needs to come first so its underneath the circle...
    .attr("class", "reach")
    .attr('r', reachableDistanceFromStop)
  map.on("move", ->
    layer.selectAll("g").attr("transform", transform)
    layer.selectAll("g").selectAll("circle.reach").attr('r', reachableDistanceFromStop)
  )

map.add(po.compass().pan("none"))

do -> d3.json('data/uvic_transit.json', (json) ->
  # order of layers important because of SVG drawing
  createBusStopReachLayer(json.stops)
  createBusRouteLayer(json.routes,json.stops)
  createBusStopLayer(json.stops)
)