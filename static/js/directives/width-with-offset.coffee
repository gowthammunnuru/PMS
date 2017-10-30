"use strict"

angular.module("perform").directive "widthWithOffset", [

  "$window"

  ($window) ->

    link: (scope, element, attrs) ->

      gutter = 30

      scope.window = $window

      getWidth = () -> $window.innerWidth

      scope.$watch getWidth, (newValue, oldValue) ->
        element.width(newValue - attrs.widthWithOffset - gutter)

      angular.element($window).bind 'resize', () -> scope.$apply()

      return
]
