"use strict"

angular.module("perform").directive "review", [

  () ->
    restrict: "E"
    transclude: true
    template: (element, attrs) ->

      return "<span class='review-title'></span>"

      if attrs.mode == "preview"
        return "<span class='preview-review-title' ng-transclude></span>"
      else
        return "<span class='review-title'></span>"
]
