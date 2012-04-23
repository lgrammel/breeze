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

# assume you can walk 500m in 6min, this seems to be a good default distance
distanceInMeters = 500

# Calculates pixel for 1km distance
# http://jan.ucc.nau.edu/~cvm/latlongdist.html with 0N 0W to 0N 0.008983W is 1km
reachableDistanceFromStop  = () ->
  pixelsPerKm = map.locationPoint({ lat: 0, lon: 0.008983 }).x - map.locationPoint({ lat: 0, lon: 0 }).x
  distanceInMeters / 1000 * pixelsPerKm

# Lat/Lng transform function
transform = (location) ->
  d = map.locationPoint(location)
  "translate(" + d.x + "," + d.y + ")"

# Classes
class Layer
  constructor: ->
    @selector = d3.select("#map svg").insert("svg:g")

class DistanceLayer extends Layer
  constructor: ->
    super
    map.on("move", =>
      @selector.selectAll("g").attr("transform", transform)
      @update()
    )
  update: ->
    @selector.selectAll("circle.reach").attr('r', reachableDistanceFromStop)
  addStops: (stops) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(stops).enter().append("g").attr("transform", transform)
    marker.append("circle").attr("class", "reach").attr('r', reachableDistanceFromStop)

class BusRouteLayer extends Layer
  addRoutes: (routes, stops) ->
    # TODO prevent overplotting by intelligently selecting route segments between stops
    # map stops by their id
    stopsById = {}
    stops.forEach((stop) ->
      stopsById[stop.id] = stop
    )

    svgLine = d3.svg.line().x((d) -> d.x).y((d) -> d.y).interpolate("linear")
    line = (route) -> svgLine(route.stops.map((routeStop) -> map.locationPoint(stopsById[routeStop.point_id])))
    @selector.selectAll("g").data(routes).enter().append("path").attr("class", "route").attr("d", (d) -> line(d))
    # XXX should not be called multiple times
    map.on("move", =>
      @selector.selectAll("path").attr("d", (d) -> line(d))
    )

class BusStopLayer extends Layer
  constructor: ->
    super
    map.on("move", =>
      @selector.selectAll("g").attr("transform", transform)
    )
  addStops: (stops) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(stops).enter().append("g").attr("transform", transform)
    marker.append("circle").attr("class", "stop").attr('r', 3.5).attr("text", (stop) -> stop.routes)

    $(".stop").qtip(
      content:
        attr: 'text'
    )

class RentalsLayer extends Layer
  constructor: ->
    super
    map.on("move", =>
      @selector.selectAll("g").attr("transform", transform)
    )
  addRentals: (rentals) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(rentals).enter().append("g").attr("transform", transform)
    marker.append("rect")
    .attr("class", "rental")
    .attr("x", -8/2)
    .attr("y", -8/2)
    .attr('height', 8)
    .attr('width', 8)
    .attr("text", (rentals) =>
      (" " + suite.bedrooms + " bedroom: " + if suite.price > 0 then "$" + suite.price else "Unknown") for suite in rentals.availabilities
    )
    .on("click", (rentals) ->
      window.open(rentals.url)
    )

    $(".rental").qtip(
      content:
        attr: 'text'
    )

# create layers - order of layers important because of SVG drawing
distanceLayer = new DistanceLayer
busRouteLayer = new BusRouteLayer
busStopLayer = new BusStopLayer
rentalLayer = new RentalsLayer

# TODO decouple using events, e.g. from backbone --> route event, location, zoom on url
setupDistanceSlider = () ->
  # TODO support multiple event listers
  sliderChanged = (value) ->
    $( "#slider-distance > .value" ).html( value + "m" )
    distanceInMeters = value
    distanceLayer.update()

  $("#slider-distance-element").slider(
    range: "min"
    value: distanceInMeters
    min: 0
    max: 2500
    slide: (event, ui) -> sliderChanged(ui.value)
  )

  sliderChanged($("#slider-distance-element").slider("value"))
  
loadBusRoutes = () ->
  d3.json 'data/uvic_transit.json', (json) ->
    distanceLayer.addStops json.stops
    busRouteLayer.addRoutes json.routes,json.stops
    busStopLayer.addStops json.stops

loadRentals = () ->
  d3.json 'data/rentals.json', (json) ->
    rentalLayer.addRentals json

do ->
  setupDistanceSlider()
  loadBusRoutes()
  loadRentals()
