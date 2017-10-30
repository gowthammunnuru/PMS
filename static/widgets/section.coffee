"use strict"

angular.module("perform").directive "section", [

  () ->

    restrict: 'E'
    transclude: true
    template: '<h3 ng-transclude></h3>'
]
