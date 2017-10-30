"use strict"

angular.module("perform").service "NineBox", [

  () ->

    @cache = {}


    @ratings = {

      0:
        name   : "Too New / NA"
        weight :
          performance : 0
          potential   : 0
      1:
        name   : "Improvement Needed"
        weight :
          performance : 1
          potential   : 1
      2:
        name   : "Inconsistant"
        weight :
          performance : 3
          potential   : 2
      3:
        name   : "Developing"
        weight :
          performance : 3
          potential   : 5
      4:
        name   : "Achieves"
        weight :
          performance : 5
          potential   : 5
      5:
        name   : "Achieves+"
        weight :
          performance : 5.5
          potential   : 6
      6:
        name   : "Exceeds"
        weight :
          performance : 8
          potential   : 8
    }

    @ratingFn = (rating, token) -> @ratings[rating].weight[token]



    @_getBoxEdges = (ratings, weights) ->

      allModelKeys = weights.contents.modelkeys
      weightsX     = weights['weights-performance'].latest_review.review_body
      weightsY     = weights['weights-potential'].latest_review.review_body

      scoreX_min    = 0
      scoreX_normal = 0
      scoreX_max    = 0

      scoreY_min    = 0
      scoreY_normal = 0
      scoreY_max    = 0

      for name, rating of ratings

        # Only consider modelkeys in the current template
        if name not in allModelKeys
          continue

        # We dont care about modekykeys that are not ratings
        if not name.match /ratings/
          continue

        weightX = weightsX?[name]
        if not _.isNumber(weightX)
          weightX = 3

        weightY = weightsY?[name]
        if not _.isNumber(weightY)
          weightY = 3


        scoreX_min    += weightX * @ratingFn(0, "performance")
        scoreX_normal += weightX * @ratingFn(4, "performance")
        scoreX_max    += weightX * @ratingFn(6, "performance")


        scoreY_min    += weightY * @ratingFn(0, "potential")  # NA
        scoreY_normal += weightY * @ratingFn(4, "potential")  # Achives
        scoreY_max    += weightY * @ratingFn(6, "potential")  # Exceeds


      edgeX = (scoreX_max - scoreX_min) / 3
      edgeY = (scoreY_max - scoreY_min) / 3

      console.log(scoreX_min, scoreX_normal, scoreX_max, edgeX)
      console.log(scoreY_min, scoreY_normal, scoreY_max, edgeY)

      edges =
        x:
          min: scoreX_min
          max: scoreX_max
          normal: scoreX_normal
          edge: edgeX
        y:
          min: scoreY_min
          max: scoreY_max
          normal: scoreY_normal
          edge: edgeY

      console.log(edges)
      return edges

    @_getPercent = (score, edge) ->

      longEdge = edge.max - edge.min
      currEdge = score - edge.min

      if currEdge == 0
        percent = 0
      else
        percent = currEdge / longEdge

      return percent

    @_getPosition = (edges, scoreX, scoreY) ->

      percentX = _.max([_.min([@_getPercent(scoreX, edges.x), 1]), 0])
      percentY = _.max([_.min([@_getPercent(scoreY, edges.y), 1]), 0])

      x = _.max([_.min([Math.floor(3 * percentX), 2]), 0])
      y = _.max([_.min([Math.floor(3 * percentY), 2]), 0])

      console.log("Position (internal): #{x}, #{y}")
      console.log("Position (display):  #{x}, #{2 - y}")

      data =
        pos: [x, 2 - y]
        percent: [percentX, percentY]
        percent_str: [Math.round(percentX * 100), Math.round(percentY * 100)]

      return data

    @calculateScore = (review, weights) ->

      ratings = review.review_body ||  {}

      allModelKeys = weights.contents.modelkeys
      weightsX     = weights['weights-performance'].latest_review.review_body
      weightsY     = weights['weights-potential'].latest_review.review_body

      scoreX = 0

      for name, rating of ratings

        # Only consider modelkeys in the current template
        if name not in allModelKeys
          continue

        if _.isNumber(rating)
          # If the weights for the template are not yet assigned, assume 3 (= Important)
          weight = weightsX?[name]

          if not _.isNumber(weight)
            weight = 3

          scoreX += @ratingFn(rating, "performance") * weight

      scoreY = 0

      for name, rating of ratings

        # Only consider modelkeys in the current template
        if name not in allModelKeys
          continue

        if _.isNumber(rating)
          # If the weights for the template are not yet assigned, assume 3 (= Important)
          weight = weightsY?[name]

          if not _.isNumber(weight)
            weight = 3

          scoreY += @ratingFn(rating, "potential") * weight


      return [scoreX, scoreY]

    @calculate = (review, weights) ->

      ratings = review.review_body

      [scoreX, scoreY] = @calculateScore(review, weights)

      console.log("[ninebox]: scores: #{review.uid}: #{scoreX}, #{scoreY}")

      edges = @_getBoxEdges(ratings, weights)

      pos = @_getPosition(edges, scoreX, scoreY)

      console.log("[ninebox]: position: #{review.uid}: #{pos}")

      data =
        pos: pos.pos
        percent: pos.percent
        percent_str: pos.percent_str
        score: [scoreX, scoreY]

      return data

    return

]
