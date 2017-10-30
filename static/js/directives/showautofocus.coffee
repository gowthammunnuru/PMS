"use strict"

angular.module("perform").directive "showautofocus", [
  "$timeout"
  ($timeout) ->
    (scope, element, attrs) ->
      scope.$watch attrs.showautofocus, ((newValue) ->
        $timeout ->
          newValue and element.focus()
          return
        return
      ), true
]
