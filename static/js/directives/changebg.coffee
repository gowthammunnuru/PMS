"use strict"

angular.module("perform").directive "changebg", [

  "$interval"
  "Colors"

  ($interval, Colors) ->

    restrict: "A"
    templateUrl: 'static/js/directives/changebg.html'
    replace: true
    link: (scope, element, attrs)  ->

      scope.timeout = 500

      scope.index = 0

      scope.bar1 = angular.element('.bar1', element)
      scope.bar2 = angular.element('.bar2', element)
      scope.expand = false


      isActive = () -> scope.$eval(attrs.changebg)

      update = () ->

        if scope.expand
          scope.bar1.attr('style', "background-color: #{scope.color}")
          scope.bar2.attr('style', "width: 0%; margin-left: 50%; background-color: rgba(0,0,0,0)")
          scope.expand = false
        else
          newColor = Colors.color()

          while newColor is scope.color
            newColor = Colors.color()

          scope.color = newColor
          scope.bar2.attr('style', "width: 100%; margin-left: 0%; background-color: #{scope.color}")
          scope.expand = true

      hide = () ->
        scope.index = 0
        scope.bar2.attr('style', "width: 0%; margin-left: 50%; background-color: rgba(0,0,0,0)")
        scope.bar1.attr('style', "background-color: rgba(0,0,0,0)")

      scope.$watch isActive, (newValue, oldValue) ->


        if not newValue
          $interval.cancel(scope.promise)
          delete scope.promise
          hide()
        else
          if not scope?.promise
            scope.promise = $interval () ->

              update()

            , scope.timeout

            scope.bar1.attr('style', "background-color: rgba(0,0,0,0)")
      , true



      return


]
