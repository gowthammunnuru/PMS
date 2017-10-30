"use strict"

angular.module("perform").directive "page", [
  () ->
    restrict: 'E'
    transclude: true
    template: '<div class="preview-page" ng-transclude></div>'
]
