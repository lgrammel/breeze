if Modernizr.svg and Modernizr.inlinesvg
  # Code based on Polymaps example from Mike Bostock http://bl.ocks.org/899670
  polymaps = org.polymaps

  map = polymaps.map().container(d3.select("#map").append("svg:svg").attr("width", "100%").attr("height", "100%").node())
  .zoom(13)
  .center({lat: 48.455164, lon: -123.351059})# Victoria BC west of Cedar Hill Golf Course
  .add(polymaps.drag())
  .add(polymaps.wheel().smooth(false))
  .add(polymaps.dblclick())
  .add(polymaps.arrow())
  .add(polymaps.touch())

  # Stamen toner tiles http://maps.stamen.com
  map.add(polymaps.image().url(polymaps.url("http://tile.stamen.com/toner/{Z}/{X}/{Y}.png")))

  # Classes
  class Layer
    constructor: (@map) ->
      @selector = d3.select("#map svg").insert("svg:g")
      @map.on "move", => @update()
      @map.on "resize", => @update()

    # Lat/Lng transform function
    transform: (location) =>
      d = @map.locationPoint(location)
      "translate(" + d.x + "," + d.y + ")"

  class DistanceLayer extends Layer
    update: ->
      @selector.selectAll("g").attr("transform", @transform)
      @updateCircleRadius()

    distanceInMeters = (if $.cookie("distance") then $.cookie("distance") else 500) # (private) assume you can walk 500m in 6min, this seems to be a good default distance
    distanceInMeters: () ->
      if arguments.length == 0
        distanceInMeters
      else
        distanceInMeters = arguments[0]
        $.cookie("distance",distanceInMeters, { expires: 30 })
        setVariable(1,"Distance",distanceInMeters.toString())
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
      marker.append("circle")
      .attr("class", "stop")
      .attr('r', 3.5)
      .attr("text", (stop) -> "<ul>" + (("<li>" + route + "</li>") for route in stop.routes).join("") + "</ul>")

      if (not Modernizr.touch)
        $(".stop").qtip(
          content:
            attr: 'text'
          show: 'mouseover'
          hide: 'mouseout'
        )

  #$.cookie("viewed-listings") then JSON.parse($.cookie("viewed-listings")

  class RentalsLayer extends Layer
    viewedIndices: (if $.cookie("viewed-listings") then JSON.parse($.cookie("viewed-listings")) else new Object())
    rentalClass: (rental, i) =>
      if (@viewedIndices.hasOwnProperty(rental.id))
        if (rental.updated_at > @viewedIndices[rental.id])
          delete @viewedIndices[rental.id]
          "rental"
        else "rental rental-viewed"
      else "rental"

    priceRange = (if $.cookie("priceLow") and $.cookie("priceHigh") then [$.cookie("priceLow"),$.cookie("priceHigh")] else [0,3000]) # (private) assume you can walk 500m in 6min, this seems to be a good default distance
    priceRange: () ->
      if arguments.length == 0
        priceRange
      else
        priceRange = arguments[0]
        $.cookie("priceLow",priceRange[0], { expires: 30 })
        $.cookie("priceHigh",priceRange[1], { expires: 30 })
        setVariable(2,"Price Low",priceRange[0].toString())
        setVariable(3,"Price High",priceRange[1].toString())
        @updateVisibility()
        this

    roomsRange = (if $.cookie("roomsLow") and $.cookie("roomsHigh") then [$.cookie("roomsLow"),$.cookie("roomsHigh")] else [0,5]) # (private) assume you can walk 500m in 6min, this seems to be a good default distance
    roomsRange: () ->
      if arguments.length == 0
        roomsRange
      else
        roomsRange = arguments[0]
        $.cookie("roomsLow",roomsRange[0], { expires: 30 })
        $.cookie("roomsHigh",roomsRange[1], { expires: 30 })
        setVariable(4,"Min Rooms", roomsRange[0].toString())
        setVariable(5,"Max Rooms", roomsRange[1].toString())
        @updateVisibility()
        this

    allowShared = (if $.cookie("showShared") then $.cookie("showShared") == "true" else false) # (private) assume you can walk 500m in 6min, this seems to be a good default distance
    allowShared: () ->
      if arguments.length == 0
        allowShared
      else
        allowShared = arguments[0]
        $.cookie("showShared",allowShared, { expires: 30 })
        @updateVisibility()
        this

    isNotSharedOrAllowed: (rental) ->
      match = /shared|room/i.test(rental.type)
      if match
        allowShared
      else
        true

    updateVisibility: ->
      @selector.selectAll("rect").attr('visibility', (rentals) =>
        suites = (suite for suite in rentals.availabilities when suite && priceRange[0] <= suite.price <= priceRange[1] && roomsRange[0] <= suite.bedrooms <= roomsRange[1] )

        if suites.length > 0
          if @isNotSharedOrAllowed(rentals) then 'visible' else 'hidden'
        else
          'hidden'
      )

    update: ->
      @selector.selectAll("g").attr("transform", @transform)
      $(".rental").qtip('reposition')

    convertDateToUTC: (date) ->
      return new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds())

    setListingDisplay: (rental) ->
      listings = (("<li>" + suite.bedrooms + " bedroom: " + (if suite.price > 0 then "$" + suite.price else "Unknown") + "</li>" ) for suite in rental.availabilities)

      output = ""
      if rental.image_url
        output = output + "<a href=\"" + rental.url + "\" target=\"_blank\" onClick=\"recordOutboundLink(this, 'Outbound Links', '" + rental.url + "', '" + rental.source + "');return false;\"><img class=\"rental-img\" src=\""+ rental.image_url + "\"></a>"
      output = output + rental.source + ", " + rental.type + " <br/><ul>" + listings.join("") + "</ul><br /><a href=\"" + rental.url + "\" target=\"_blank\" onClick=\"recordOutboundLink(this, 'Outbound Links', '" + rental.url + "', '" + rental.source + "');return false;\">View Original Listing</a>"
      output

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
        @setListingDisplay(rental)
      )
      @updateVisibility()

      marker.on("click", (rental, i) =>
        @viewedIndices[rental.id] = new Date()*1
        $.cookie("viewed-listings", JSON.stringify(@viewedIndices), { expires: 30 })
        @selector.selectAll("g").select("rect").attr("class", @rentalClass)
        recordEvent('Rental View',rental.url,rental.source)
      )

      $(".rental").qtip(
        content:
          attr: 'text'
          title:
            text: 'Rental Details'
            button: true
        show: 'mousedown'
        hide: false
        position:
          my: 'bottom center'
          at: 'top center'
        style: 'ui-tooltip-tipped'
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

  setupSharedCheckbox = () ->
    $("#show-shared").attr 'checked', rentalLayer.allowShared()
    $("#show-shared").click ->
      rentalLayer.allowShared(this.checked)

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
    setupSharedCheckbox()

    loadBusRoutes()
    loadRentals()

else
  $('#unsupportedBrowser').show();
  $('.regular').hide();
  recordEvent('Unsupported Browser',"","")
