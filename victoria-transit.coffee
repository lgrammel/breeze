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

# Classes
class Layer
  constructor: (@map) ->
    @selector = d3.select("#map svg").insert("svg:g")
    @map.on "move", => @update()

  # Lat/Lng transform function
  transform: (location) =>
    d = @map.locationPoint(location)
    "translate(" + d.x + "," + d.y + ")"

class DistanceLayer extends Layer
  update: ->
    @selector.selectAll("g").attr("transform", @transform)
    @updateCircleRadius()

  distanceInMeters = 500 # (private) assume you can walk 500m in 6min, this seems to be a good default distance
  distanceInMeters: () ->
    if arguments.length == 0
      distanceInMeters
    else
      distanceInMeters = arguments[0]
      @updateCircleRadius()
      this

  distanceInPixels: () ->
    # Calculates pixel for 1km distance
    # http://jan.ucc.nau.edu/~cvm/latlongdist.html with 0N 0W to 0N 0.008983W is 1km
    pixelsPerKm = @map.locationPoint({ lat: 0, lon: 0.008983 }).x - @map.locationPoint({ lat: 0, lon: 0 }).x
    @distanceInMeters() / 1000 * pixelsPerKm

  updateCircleRadius: ->
    @selector.selectAll("circle.reach").attr('r', @distanceInPixels())

  addStops: (stops) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(stops).enter().append("g").attr("transform", @transform)
    marker.append("circle").attr("class", "reach").attr('r', @distanceInPixels())

class BusRouteLayer extends Layer
  svgLine = d3.svg.line().x((d) -> d.x).y((d) -> d.y).interpolate("linear")

  update: () -> @selector.selectAll("path").attr("d", (d) => @line(d))
  addRoutes: (routes, stops) ->
    # TODO prevent overplotting by intelligently selecting route segments between stops
    # map stops by their id
    stopsById = {}
    stops.forEach((stop) ->
      stopsById[stop.id] = stop
    )

    @line = (route) -> svgLine(route.stops.map((routeStop) => @map.locationPoint(stopsById[routeStop.point_id])))
    @selector.selectAll("g").data(routes).enter().append("path").attr("class", "route").attr("d", (d) => @line(d))

class BusStopLayer extends Layer
  update: -> @selector.selectAll("g").attr("transform", @transform)
  addStops: (stops) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(stops).enter().append("g").attr("transform", @transform)
    marker.append("circle").attr("class", "stop").attr('r', 3.5).attr("text", (stop) -> stop.routes)

    $(".stop").qtip(
      content:
        attr: 'text'
    )

class RentalsLayer extends Layer
  viewedIndices: []
  rentalClass: (rental, i) =>
    if (@viewedIndices.indexOf(i) > -1) then "rental-viewed" else "rental"
    
  priceRange = [0,5000] # (private) assume you can walk 500m in 6min, this seems to be a good default distance
  priceRange: () ->
    if arguments.length == 0
      priceRange
    else
      priceRange = arguments[0]
      @updateVisibility()
      this  
      
  roomsRange = [0,5] # (private) assume you can walk 500m in 6min, this seems to be a good default distance
  roomsRange: () ->
    if arguments.length == 0
      roomsRange
    else
      roomsRange = arguments[0]
      @updateVisibility()
      this        
      
  updateVisibility: ->
    @selector.selectAll("rect").attr('visibility', (rentals) =>
      suites = (suite for suite in rentals.availabilities when suite && priceRange[0] <= suite.price <= priceRange[1] && roomsRange[0] <= suite.bedrooms <= roomsRange[1] )
      

      if suites.length > 0
        'visible'
      else
        'hidden'
    )

  update: -> @selector.selectAll("g").attr("transform", @transform)
  addRentals: (rentals) ->
    # TODO just have a single g element that is transformed
    marker = @selector.selectAll("g").data(rentals).enter().append("g").attr("transform", @transform)
    marker.append("rect")
    .attr("class", @rentalClass)
    .attr("x", -8/2)
    .attr("y", -8/2)
    .attr('height', 8)
    .attr('width', 8)
    .attr("text", (rental) => 
      listings = (("<li>" + suite.bedrooms + " bedroom: " + (if suite.price > 0 then "$" + suite.price else "Unknown") + "</li>" ) for suite in rental.availabilities)
      rental.source + ", " + rental.type + " <br/><ul>" + listings.join("") + "</ul>"
    )
    .on("click", (rental, i) =>
      window.open(rental.url)
      @viewedIndices.push(i)
      @selector.selectAll("g").select("rect").attr("class", @rentalClass)
    )

    $(".rental").qtip(
      content:
        attr: 'text'
    )

# create layers - order of layers important because of SVG drawing
distanceLayer = new DistanceLayer map
busRouteLayer = new BusRouteLayer map
busStopLayer = new BusStopLayer map
rentalLayer = new RentalsLayer map

# TODO decouple using events, e.g. from backbone --> route event, location, zoom on url
setupDistanceSlider = () ->
  # TODO support multiple event listers
  sliderChanged = (value) ->
    $( "#slider-distance > .value" ).html( value + "m" )
    distanceLayer.distanceInMeters(value)

  $("#slider-distance-element").slider(
    range: "min"
    value: distanceLayer.distanceInMeters()
    step: 10
    min: 0
    max: 2500
    slide: (event, ui) -> sliderChanged(ui.value)
  )

  sliderChanged($("#slider-distance-element").slider("value"))
  
# TODO decouple using events, e.g. from backbone --> route event, location, zoom on url
setupPriceSlider = () ->
  # TODO support multiple event listers
  sliderChanged = (values) ->
    $( "#slider-price > .value" ).html( "$" + values[0] + " - " + values[1]  )
    rentalLayer.priceRange(values)

  $("#slider-price-element").slider(
    range: true
    values: rentalLayer.priceRange()
    step: 50
    min: 0
    max: 3000
    slide: (event, ui) -> sliderChanged(ui.values)
  )

  sliderChanged($("#slider-price-element").slider("values"))
  
# TODO decouple using events, e.g. from backbone --> route event, location, zoom on url
setupRoomsSlider = () ->
  # TODO support multiple event listers
  sliderChanged = (values) ->
    $( "#slider-rooms > .value" ).html( values[0] + " - " + values[1] + " rooms"  )
    rentalLayer.roomsRange(values)

  $("#slider-rooms-element").slider(
    range: true
    values: rentalLayer.roomsRange()
    min: 0
    max: 5
    slide: (event, ui) -> sliderChanged(ui.values)
  )

  sliderChanged($("#slider-rooms-element").slider("values"))
  
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
  setupPriceSlider()
  setupRoomsSlider()
  loadBusRoutes()
  loadRentals()
