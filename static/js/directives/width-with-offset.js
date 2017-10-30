// Generated by CoffeeScript 1.8.0
"use strict";
angular.module("perform").directive("widthWithOffset", [
  "$window", function($window) {
    return {
      link: function(scope, element, attrs) {
        var getWidth, gutter;
        gutter = 30;
        scope.window = $window;
        getWidth = function() {
          return $window.innerWidth;
        };
        scope.$watch(getWidth, function(newValue, oldValue) {
          return element.width(newValue - attrs.widthWithOffset - gutter);
        });
        angular.element($window).bind('resize', function() {
          return scope.$apply();
        });
      }
    };
  }
]);