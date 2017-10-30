"use strict"

angular.module("perform").directive "ninebox", [

  "NineBox"
  "$window"
  "Colors"

  (NineBox, $window, Colors) ->

    restrict: "E"
    templateUrl:  "static/widgets/ninebox.html"
    link: (scope, element, attrs) ->

      scope.cellheight = attrs.cellheight

      scope.metadata = [
        title: "Emerging"
        rank: "C"
        index_str: "zero"
      ,
        title: "Rising Star"
        rank: "B"
        index_str: "one"
      ,
        title: "Superstar"
        rank: "A"
        index_str: "two"
      ,
        title: "Requires Attention"
        rank: "D"
        index_str: "three"
      ,
        title: "Solid"
        rank: "C"
        index_str: "four"
      ,
        title: "High Performer"
        rank: "B"
        index_str: "five"
      ,
        title: "Unacceptable"
        rank: "E"
        index_str: "six"
      ,
        title: "Specific Castability"
        rank: "D"
        index_str: "seven"
      ,
        title: "Key Contributor"
        rank: "C"
        index_str: "eight"

      ]

      scope.colors =
        A: Colors.colorScheme.darkgreen
        B: Colors.colorScheme.green
        C: Colors.colorScheme.lightgreen
        D: Colors.colorScheme.lime
        E: Colors.colorScheme.amber

      scope.NineBox = NineBox

      scope.update = () ->

        # initialize matrix
        scope.matrix = [

          [ [], [], [] ],
          [ [], [], [] ],
          [ [], [], [] ],

        ]

        positions = (NineBox.calculate(review, scope.template) for review in scope.reviews)

        for item in _.zip(scope.users, positions, scope.reviews)

          [user, nineBoxData, review] = item

          x = nineBoxData.pos[0]
          y = nineBoxData.pos[1]

          user.ninebox = nineBoxData
          user.review  = review

          scope.matrix[y][x].push(user)

        for x in [0, 1, 2]
          for y in [0, 1, 2]
            scope.matrix[y][x] = _.sortBy scope.matrix[y][x], (item) -> -item?.ninebox?.percent?.reduce (a, b) -> a + b

      scope.$watch 'reviews', (newValue, oldValue) ->

        scope.update()

      , true



      return


]
