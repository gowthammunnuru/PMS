"use strict"

angular.module("perform").directive "autofocus", [
  () ->
    link: (scope, element, attrs) ->
      element.focus()
      return

]
