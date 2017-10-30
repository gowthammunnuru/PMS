"use strict"

angular.module("perform").directive "previewFooter", [

  () ->

    restrict: 'E'
    scope: true
    templateUrl: 'static/widgets/previewFooter.html'
    link: (scope, element, attrs) ->

      return

]
