class Morris.Bar extends Morris.Grid
  constructor: (options) ->
    return new Morris.Bar(options) unless (@ instanceof Morris.Bar)
    super(Morris.extend {}, options, parseTime: false)

  init: ->
    @cumulative = @options.stacked

    if @options.hideHover isnt 'always'
      @hover = new Morris.Hover(parent: @el)
      @on('hovermove', @onHoverMove)
      @on('hoverout', @onHoverOut)
      @on('gridclick', @onGridClick)

  # Default configuration
  #
  defaults:
    barSizeRatio: 0.75
    barGap: 3
    barColors: [
      '#2f7df6'
      '#53a351'
      '#f6c244'
      '#cb444a'
      '#4aa0b5'
      '#222529'
    ],
    barOpacity: 1.0
    barHighlightOpacity: 1.0
    highlightSpeed: 150
    barRadius: [0, 0, 0, 0]
    xLabelMargin: 50
    horizontal: false
    stacked: false
    shown: true
    inBarValue: false
    inBarValueTextColor: 'white'
    inBarValueMinTopMargin: 1
    inBarValueRightMargin: 4

  # Do any size-related calculations
  #
  # @private
  calc: ->
    @calcBars()
    if @options.hideHover is false
      @hover.update(@hoverContentForRow(@data.length - 1)...)

  # calculate series data bars coordinates and sizes
  #
  # @private
  calcBars: ->
    for row, idx in @data
      row._x = @xStart + @xSize * (idx + 0.5) / @data.length
      row._y = for y, ii in row.y
        if ii < @options.ykeys.length - @options.nbYkeys2
          if y? then @transY(y) else null
      row._y2 = for y, ii in row.y
        if ii >= @options.ykeys.length - @options.nbYkeys2
          if y? then @transY2(y) else null

  # Draws the bar chart.
  #
  draw: ->
    @drawXAxis() if @options.axes in [true, 'both', 'x']
    @drawSeries()
    @drawBarLine()
    @drawBarPoints()

  drawBarLine: ->
    nb = @options.ykeys.length - @options.nbYkeys2
    for dim, ii in @options.ykeys[nb...@options.ykeys.length] by 1
      path = ""
      if @options.horizontal is not true
        coords = ({x: r._x, y: r._y2[nb+ii]} for r in @data when r._y2[nb+ii] isnt undefined)
      else
        coords = ({x: r._y2[nb+ii], y: r._x} for r in @data when r._y2[nb+ii] isnt undefined)
      grads = Morris.Line.gradients(coords) if @options.smooth
      prevCoord = {y: null}
      for coord, i in coords
        if coord.y?
          if prevCoord.y?
            if @options.smooth and @options.horizontal is not true
              g = grads[i]
              lg = grads[i - 1]
              ix = (coord.x - prevCoord.x) / 4
              x1 = prevCoord.x + ix
              y1 = Math.min(@bottom, prevCoord.y + ix * lg)
              x2 = coord.x - ix
              y2 = Math.min(@bottom, coord.y - ix * g)
              path += "C#{x1},#{y1},#{x2},#{y2},#{coord.x},#{coord.y}"
            else
              path += "L#{coord.x},#{coord.y}"
          else
            if not @options.smooth or grads[i]?
              path += "M#{coord.x},#{coord.y}"
        prevCoord = coord

      if @options.animate
        straightPath = path;
        straightPath = path.replace('A', ',');
        straightPath = straightPath.replace('M', '');
        straightPath = straightPath.replace('C', ',');
        straightDots = straightPath.split(',');
        average = (parseFloat(straightDots[1])+parseFloat(straightDots[straightDots.length-1]))/2
        straightPath = 'M'+straightDots[0]+','+average+','+straightDots[straightDots.length-2]+','+average;
        rPath = @raphael.path(straightPath)
                        .attr('stroke', @options.barColors[nb+ii])
                        .attr('stroke-width', 3)
        do (rPath, path) =>
          rPath.animate {path}, 500, '<>'
      else
        rPath = @raphael.path(path)
                        .attr('stroke', @options.barColors[nb+ii])
                        .attr('stroke-width', 3)

  drawBarPoints: ->
    nb = @options.ykeys.length - @options.nbYkeys2
    for dim, ii in @options.ykeys[nb...@options.ykeys.length] by 1
      for row, idx in @data
        if row._y2[nb+ii]?
          if @options.horizontal is not true
            @raphael.circle(row._x, row._y2[nb+ii], 4)
              .attr('fill', @options.barColors[nb+ii])
              .attr('stroke-width', 1)
              .attr('stroke', '#ffffff')
          else
            @raphael.circle(row._y2[nb+ii], row._x, 4)
              .attr('fill', @options.barColors[nb+ii])
              .attr('stroke-width', 1)
              .attr('stroke', '#ffffff')

          if @options.dataLabels
            if @options.horizontal is not true
              @drawDataLabel(row._x, row._y2[nb+ii] - 10, @yLabelFormat(row.y[nb+ii]))
            else
              @drawDataLabelExt(row._y2[nb+ii] + 10, row._x, @yLabelFormat(row.y[nb+ii]), 'start')
              
  # draw the x-axis labels
  #
  # @private
  drawXAxis: ->
    # draw x axis labels
    if not @options.horizontal
      basePos = @getXAxisLabelY()
    else
      basePos = @getYAxisLabelX()

    prevLabelMargin = null
    prevAngleMargin = null
    for i in [0...@data.length]
      row = @data[@data.length - 1 - i]
      if not @options.horizontal
        label = @drawXAxisLabel(row._x, basePos, row.label)
      else
        label = @drawYAxisLabel(basePos, row._x - 0.5 * @options.gridTextSize, row.label)


      if not @options.horizontal
        angle = @options.xLabelAngle
      else
        angle = 0

      textBox = label.getBBox()
      label.transform("r#{-angle}")
      labelBox = label.getBBox()
      label.transform("t0,#{labelBox.height / 2}...")


      if angle != 0
        offset = -0.5 * textBox.width *
          Math.cos(angle * Math.PI / 180.0)
        label.transform("t#{offset},0...")

      {width, height} = Morris.dimensions @el
      if not @options.horizontal
        startPos = labelBox.x
        size = labelBox.width
        maxSize = width
      else
        startPos = labelBox.y
        size = labelBox.height
        maxSize = height

      # try to avoid overlaps
      if (not prevLabelMargin? or
          prevLabelMargin >= startPos + size or
          prevAngleMargin? and prevAngleMargin >= startPos) and
         startPos >= 0 and (startPos + size) < maxSize
        if angle != 0
          margin = 1.25 * @options.gridTextSize /
            Math.sin(angle * Math.PI / 180.0)
          prevAngleMargin = startPos - margin
        if not @options.horizontal
          prevLabelMargin = startPos - @options.xLabelMargin
        else
          prevLabelMargin = startPos

      else
        label.remove()

  # get the Y position of a label on the X axis
  #
  # @private
  getXAxisLabelY: ->
    @bottom + (@options.xAxisLabelTopPadding || @options.padding / 2)

  # draw the data series
  #
  # @private
  drawSeries: ->
    @seriesBars = []
    groupWidth = @xSize / @options.data.length

    if @options.stacked
      numBars = 1
    else
      numBars = 0
      for i in [0..@options.ykeys.length-1]
        if @hasToShow(i)
          numBars += 1

    if @options.stacked is not true
      numBars = numBars - @options.nbYkeys2
    barWidth = (groupWidth * @options.barSizeRatio - @options.barGap * (numBars - 1)) / numBars
    barWidth = Math.min(barWidth, @options.barSize) if @options.barSize
    spaceLeft = groupWidth - barWidth * numBars - @options.barGap * (numBars - 1)
    leftPadding = spaceLeft / 2
    zeroPos = if @ymin <= 0 and @ymax >= 0 then @transY(0) else null
    @bars = for row, idx in @data
      @seriesBars[idx] = []
      lastTop = 0
      nb = row._y.length - @options.nbYkeys2
      for ypos, sidx in row._y[0...nb]
        if not @hasToShow(sidx)
          continue
        if ypos != null
          if zeroPos
            top = Math.min(ypos, zeroPos)
            bottom = Math.max(ypos, zeroPos)
          else
            top = ypos
            bottom = @bottom

          left = @xStart + idx * groupWidth + leftPadding
          left += sidx * (barWidth + @options.barGap) unless @options.stacked
          size = bottom - top

          if @options.verticalGridCondition and @options.verticalGridCondition(row.x)
            if not @options.horizontal
              @drawBar(@xStart + idx * groupWidth, @yEnd, groupWidth, @ySize, @options.verticalGridColor, @options.verticalGridOpacity, @options.barRadius)
            else
              @drawBar(@yStart, @xStart + idx * groupWidth, @ySize, groupWidth, @options.verticalGridColor, @options.verticalGridOpacity, @options.barRadius)


          top -= lastTop if @options.stacked
          if not @options.horizontal
            lastTop += size
            if size == 0 then size = 1
            @seriesBars[idx][sidx] = @drawBar(left, top, barWidth, size, @colorFor(row, sidx, 'bar'),
                @options.barOpacity, @options.barRadius)
            if @options.dataLabels
              if @options.stacked || @options.dataLabelsPosition=='inside'
                depth = (size)/2
              else
                depth = -7
              if size>@options.dataLabelsSize || !@options.stacked
                @drawDataLabel(left+barWidth/2,top+depth,@yLabelFormat(row.y[sidx], 0))
          else
            lastTop -= size
            if size == 0 then size = 1
            @seriesBars[idx][sidx] = @drawBar(top, left, size, barWidth, @colorFor(row, sidx, 'bar'),
                @options.barOpacity, @options.barRadius)
            if @options.dataLabels
              if @options.stacked || @options.dataLabelsPosition=='inside'
                  @drawDataLabel(top + size / 2, left + barWidth / 2,@yLabelFormat(row.y[sidx], 0))
                else
                  @drawDataLabelExt(top + size + 5, left + barWidth / 2,@yLabelFormat(row.y[sidx], 0), 'start')
            if @options.inBarValue and
                barWidth > @options.gridTextSize + 2*@options.inBarValueMinTopMargin
              barMiddle = left + 0.5 * barWidth
              @raphael.text(bottom - @options.inBarValueRightMargin, barMiddle, @yLabelFormat(row.y[sidx], sidx))
                .attr('font-size', @options.gridTextSize)
                .attr('font-family', @options.gridTextFamily)
                .attr('font-weight', @options.gridTextWeight)
                .attr('fill', @options.inBarValueTextColor)
                .attr('text-anchor', 'end')

        else
          null

    #@flat_bars = $.map @bars, (n) -> return n
    #@flat_bars = $.grep @flat_bars, (n) -> return n?
    #@bar_els = $($.map @flat_bars, (n) -> return n[0])

  # hightlight the bar on hover
  #
  # @private
  hilight: (index) ->
    if @seriesBars && @seriesBars[@prevHilight] && @prevHilight != null && @prevHilight != index
      for y,i in @seriesBars[@prevHilight]
        if y
          y.animate({'fill-opacity': @options.barOpacity}, @options.highlightSpeed)

    if @seriesBars && @seriesBars[index] && index != null && @prevHilight != index
      for y,i in @seriesBars[index]
        if y
          y.animate({'fill-opacity': @options.barHighlightOpacity}, @options.highlightSpeed)

    @prevHilight = index

  # @private
  #
  # @param row  [Object] row data
  # @param sidx [Number] series index
  # @param type [String] "bar", "hover" or "label"
  colorFor: (row, sidx, type) ->
    if typeof @options.barColors is 'function'
      r = { x: row.x, y: row.y[sidx], label: row.label, src: row.src}
      s = { index: sidx, key: @options.ykeys[sidx], label: @options.labels[sidx] }
      @options.barColors.call(@, r, s, type)
    else
      @options.barColors[sidx % @options.barColors.length]

  # hit test - returns the index of the row at the given x-coordinate
  #
  hitTest: (x, y) ->
    return null if @data.length == 0
    if not @options.horizontal
      pos = x
    else
      pos = y

    pos = Math.max(Math.min(pos, @xEnd), @xStart)
    Math.min(@data.length - 1,
      Math.floor((pos - @xStart) / (@xSize / @data.length)))

  #/
  # click on grid event handler
  #
  # @private
  onGridClick: (x, y) =>
    index = @hitTest(x, y)
    #bar_hit = !!@bar_els.filter(() -> $(@).is(':hover')).length
    @fire 'click', index, @data[index].src, x, y

  # hover movement event handler
  #
  # @private
  onHoverMove: (x, y) =>
    index = @hitTest(x, y)
    @hilight(index)
    if index?
      @hover.update(@hoverContentForRow(index)...)
    else
      @hover.hide()

  # hover out event handler
  #
  # @private
  onHoverOut: =>
    @hilight(-1)
    if @options.hideHover isnt false
      @hover.hide()

  # hover content for a point
  #
  # @private
  hoverContentForRow: (index) ->
    row = @data[index]
    content = "<div class='morris-hover-row-label'>#{row.label}</div>"

    inv = []
    for y, jj in row.y
      inv.unshift(y)

    for y, jj in inv

      j = row.y.length - 1 - jj
      if @options.labels[j] is false
        continue

      content += """
        <div class='morris-hover-point' style='color: #{@colorFor(row, j, 'label')}'>
          #{@options.labels[j]}:
          #{@yLabelFormat(y, j)}
        </div>
      """
    if typeof @options.hoverCallback is 'function'
      content = @options.hoverCallback(index, @options, content, row.src)

    if not @options.horizontal
      x = @left + (index + 0.5) * @width / @data.length
      [content, x]
    else
      x = @left + 0.5 * @width
      y = @top + (index + 0.5) * @height / @data.length
      [content, x, y, true]

  drawDataLabel: (xPos, yPos, text) ->
    label = @raphael.text(xPos, yPos, text)
                    .attr('text-anchor', 'middle')
                    .attr('font-size', @options.dataLabelsSize)
                    .attr('font-family', @options.dataLabelsFamily)
                    .attr('font-weight', @options.dataLabelsWeight)
                    .attr('fill', @options.dataLabelsColor)

  drawDataLabelExt: (xPos, yPos, text, anchor) ->
    label = @raphael.text(xPos, yPos, text)
                    .attr('text-anchor', anchor)
                    .attr('font-size', @options.dataLabelsSize)
                    .attr('font-family', @options.dataLabelsFamily)
                    .attr('font-weight', @options.dataLabelsWeight)
                    .attr('fill', @options.dataLabelsColor)

  drawBar: (xPos, yPos, width, height, barColor, opacity, radiusArray) ->
    maxRadius = Math.max(radiusArray...)
    if @options.animate
      if @options.horizontal
        if maxRadius == 0 or maxRadius > height
          path = @raphael.rect(@transY(0), yPos, 0, height).animate({x:xPos,width:width}, 500)
        else
          path = @raphael.path @roundedRect(@transY(0), yPos+height, width, 0, radiusArray).animate({y: yPos, height: height}, 500)
      else
        if maxRadius == 0 or maxRadius > height
          path = @raphael.rect(xPos, @transY(0), width, 0).animate({y:yPos, height:height}, 500)
        else
          path = @raphael.path @roundedRect(xPos, @transY(0), width, 0, radiusArray).animate({y: yPos, height: height}, 500)
    else
      if maxRadius == 0 or maxRadius > height
        path = @raphael.rect(xPos, yPos, width, height)
      else
        path = @raphael.path @roundedRect(xPos, yPos, width, height, radiusArray)
    path
      .attr('fill', barColor)
      .attr('fill-opacity', opacity)
      .attr('stroke', 'none')

  roundedRect: (x, y, w, h, r = [0,0,0,0]) ->
    [ "M", x, r[0] + y, "Q", x, y, x + r[0], y,
      "L", x + w - r[1], y, "Q", x + w, y, x + w, y + r[1],
      "L", x + w, y + h - r[2], "Q", x + w, y + h, x + w - r[2], y + h,
      "L", x + r[3], y + h, "Q", x, y + h, x, y + h - r[3], "Z" ]

