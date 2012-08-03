trackEvent = (name, values, callback = null) ->
  mixpanel.track name, values
  if callback
    callback()
  
recordOutboundLink = (link, name, values) ->
  recordEvent name, values.source, values.url
  trackEvent name, values, () -> window.open(link.href,"_blank")
window.recordOutboundLink = recordOutboundLink

recordEvent = (category, action, label) ->
  _gat._getTrackerByName()._trackEvent category, action, label
window.recordEvent = recordEvent

setVariable = (index, name, value) ->
  # This custom var is set to slot #1.  Required parameter.
  # The name acts as a kind of category for the user activity.  Required parameter.
  # This value of the custom variable.  Required parameter.
  _gaq.push ["_setCustomVar", index, name, value, 2] # Sets the scope to session-level.  Optional parameter.
window.setVariable = setVariable

if Modernizr.svg and Modernizr.inlinesvg
  if $(window).height() < 500 or $(window).width() < 500
    $(".desktop").hide()
  if Modernizr.touch
    $(".github").hide()
    
  $(".header").show()
  
  headerToggle = (element) ->
    if $("#standard-options").is(":visible")
      $("#standard-options").hide "slow"
      $(element).button "option", "icons",
        primary: "ui-icon-triangle-1-s"
      trackEvent 'hid options'
    else
      $("#standard-options").show "slow"
      $(element).button "option", "icons",
        primary: "ui-icon-triangle-1-n"
      trackEvent 'show options'
  
  $(".header-expand").button(
    icons:
      primary: "ui-icon ui-icon-triangle-1-n"
    text: false
  ).click ->
    headerToggle this
    
  toggleAdditional = ->
    if $("#additional-notices").is(":visible")
      $("#additional-notices").hide "slow"
      $("a#additional-expand").text "additional notices"
      trackEvent 'hid notices'
    else
      $("#additional-notices").show "slow"
      $("a#additional-expand").text "less notices"
      trackEvent 'show notices'
  
  $("a#additional-expand").click ->
    toggleAdditional()  
    
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
    zoomLevel: -> @map.zoom()
    
    @prevZoom = 0    
    @distance = 0

    pixelDistance: ->
      p0 = @map.pointLocation({x: 0, y: 0})
      p1 = @map.pointLocation({x: 1, y: 1})
      @distance = {lat:Math.abs(p0.lat - p1.lat),lon:Math.abs(p0.lon - p1.lon)}
      @distance      
    
    constructor: (@map) ->
      @selector = d3.select("#map svg").insert("svg:g")
      @map.on "move", => @update()
      @map.on "resize", => @update()

    # Lat/Lng transform function
    transform: (location) =>
      d = @map.locationPoint(location)
      "translate(" + d.x + "," + d.y + ")"
      
    cluster: (elements, distance) ->
      currentElements = elements.slice(0)
      pixelDistance = @pixelDistance()
      distLat = distance * pixelDistance.lat
      distLon = distance * pixelDistance.lon 
       
      
      clustered = []
      while currentElements.length > 0
        stop = currentElements.shift()
        
        cluster = []
        cluster.push stop
        
        i = 0
        while i < currentElements.length
          if Math.abs(currentElements[i].lat - stop.lat) < distLat and Math.abs(currentElements[i].lon - stop.lon) < distLon
            aStop = currentElements.splice i,1
            cluster.push aStop[0]
            i--
          i++
        clustered.push cluster  
      clustered  
      
    filter: (clusters, distance) ->
      
      tLeft = @map.pointLocation({x:0-distance,y:0-distance})
      bRight = @map.pointLocation({x: $(window).width()+distance, y: $(window).height()+distance})
       
      output = (cluster for cluster in clusters when bRight.lat <= cluster[0].lat and cluster[0].lat <= tLeft.lat and tLeft.lon <= cluster[0].lon and cluster[0].lon <= bRight.lon)
      output

  class DistanceLayer extends Layer
    stops = []
    clusters = []
    prevLocalClusters = []
    
    update: ->
      if @zoomLevel() != @prevZoom or (@stops and @prevNumStops != @stops.length)
        @prevNumStops = @stops.length
        @prevZoom = @zoomLevel()
        
        # We clustered the stops if they're within 10 pixels, do the same for the stop layer
        @clusters = @cluster(@stops,10)
      
      @localClusters = @filter(@clusters,@distanceInPixels())
      
      if (not @prevLocalClusters) or @prevLocalClusters != @localClusters
        @prevLocalClusters = @localClusters
        # Add new incoming circles
        
        marker = @selector.selectAll("g").data(@localClusters)
        marker.enter().append("g")
        .append("circle").attr("class", "reach").attr('r', @distanceInPixels())
        
        # Remove old circles
        marker.exit().remove()
        
        #Do this to all remaining circles
        @updateCircleRadius()
      
      @selector.selectAll("g").attr("transform", (cluster) => @transform cluster[0])

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
      stops.sort((a,b) -> a.lat-b.lat)
      @stops = stops
      
      # TODO just have a single g element that is transformed
      #marker = @selector.selectAll("g").data(stops).enter().append("g").attr("transform", @transform)
      #marker.append("circle").attr("class", "reach").attr('r', @distanceInPixels())
        
      @update()  

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
    clusters = []   
    stops = []
    prevNumStops = 0
    prevLocalClusters = []

    update: ->
      # If the zoom level changed, re cluster the stops
      if @zoomLevel() != @prevZoom or (@stops and @prevNumStops != @stops.length)
        @prevNumStops = @stops.length
        @prevZoom = @zoomLevel()
        
        @clusters = @cluster(@stops,10)
        
      # Filter out any stops not within an acceptable region of the screen. We'll add them as needed
      @localClusters = @filter(@clusters,10)
      if (not @prevLocalClusters) or @localClusters != @prevLocalClusters
        marker = @selector.selectAll("g").data(@localClusters)
  
        # retained markers are updated
        marker.select('circle')
        .attr('r', (cluster) -> if cluster.length > 1 then 5 else 3.5)
        .attr("text", @representCluster)
  
        # new markers are added
        marker.enter().append("g")
        .append("circle")
        .attr("class", "stop no-tip")
        .attr('r', (cluster) -> if cluster.length > 1 then 5 else 3.5)
        .attr("text", @representCluster)
  
        # old markers are removed
        marker.exit().remove()

      # TODO just have a single g element that is transformed
      @selector.selectAll("g")
      .attr("transform", (cluster) => @transform cluster[0])

    representCluster: (cluster) ->
      routes = []
      for stop in cluster
        for route in stop.routes
          routes.push route
      # This next two lines should remove duplicates
      routes = routes.sort()
      routes = (route for route, i in routes when i=0 or route != routes[i-1])
      
      # Now we sort by the numeric route value
      routes = routes.sort((a,b) -> parseInt(a.match(/^\d+/)[0]) - parseInt(b.match(/^\d+/)[0]))
      
      # Now layout the sorted routes
      "<ul>" + (("<li>" + route + "</li>") for route in routes).join("") + "</ul>"

    addStops: (stops) ->
      stops.sort((a,b) -> a.lat-b.lat)
      @stops = stops

      if (not Modernizr.touch)
        $(".stop").live("mouseover", (event) ->
          $(this).qtip(
            overwrite: false
            content:
              attr: 'text'
            show: 
              event: event.type,
              ready: true
            hide: 'mouseout'
          , event)
        )

      @update()
      
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
      listings = (("<li>" + (if suite.bedrooms then suite.bedrooms else "unknown") + " bedroom: " + (if suite.price > 0 then "$" + suite.price else "Unknown") + "</li>" ) for suite in rental.availabilities)

      output = ""
      if rental.image_url
        output = output + "<a href=\"" + rental.url + "\" target=\"_blank\" onClick=\"recordOutboundLink(this, 'Outbound Links', {\"source\":\"" + rental.source + "\", \"url\":\"" + rental.url + "\"})\"><img class=\"rental-img\" src=\""+ rental.image_url + "\"></a>"
      output = output + rental.source + ", " + rental.type + " <br/><ul>" + listings.join("") + "</ul><br /><a href=\"" + rental.url + "\" target=\"_blank\" onClick=\"recordOutboundLink(this, 'Outbound Links', {'source':'" + rental.source + "', 'url':'" + rental.url + "'});return false;\">View Original Listing</a>"
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
        recordEvent('Rental View',rental.source,rental.url)
        trackEvent('Rental View',{"Rental Source":rental.source,"url":rental.url})
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
      stop: (event, ui) -> trackEvent 'distance changed'
        distance: distanceLayer.distanceInMeters()
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
      stop: (event, ui) -> trackEvent 'price changed'
        'low price': rentalLayer.priceRange()[0]
        'high price': rentalLayer.priceRange()[1]
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
      stop: (event, ui) -> trackEvent '# rooms changed'
        'min rooms': rentalLayer.roomsRange()[0]
        'max rooms': rentalLayer.roomsRange()[1]
    )

    sliderChanged($("#slider-rooms-element").slider("values"))

  setupSharedCheckbox = () ->
    $("#show-shared").attr 'checked', rentalLayer.allowShared()
    $("#show-shared").click ->
      rentalLayer.allowShared(this.checked)
      if this.checked
        trackEvent 'shared selected'
      else
        trackEvent 'private selected'

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
    
    trackEvent('RentalMap loaded')
  
  $(window).unload( () ->
    trackEvent('RentalMap closed')
  )
  
  addthis.addEventListener('addthis.menu.share', (evt) ->
    trackEvent 'AddThis', evt.data 
  );
  
  # Set to track outbound links from the site
  $("a[rel*='external']").click(->
    link = $(this)
    recordEvent('External Link',link.text(),link.attr('href'))
    trackEvent('External Link',{"Link Text":link.text(),"url":link.attr('href')})
  )

else
  $('#unsupportedBrowser').show();
  $('.regular').hide();
  recordEvent('Unsupported Browser','No SVG' ,navigator.userAgent)
  trackEvent('Unsupported Browser',{"Browser":navigator.userAgent})
