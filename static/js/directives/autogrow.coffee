"use strict"

angular.module("perform").directive "autogrow", [

  () ->
    priority: 0
    require: '?ngModel'
    link: (scope, element, attrs, ngModel) ->

      shadow = angular.element('<p></p>').css
        position: 'absolute'
        top: -1000000
        left: -1000000
        'font-family': element.css('font-family')
        'font-weight': element.css('font-weight')
        'font-size': element.css('font-size')

      angular.element(document.body).append(shadow)


      scope.$watch () ->
        ngModel.$modelValue
      , (newValue) ->
        scope.setWidth(newValue)

      scope.setWidth = (string) ->
        if not string
          string = "Description"
        shadow.text(string)

        width = shadow[0].offsetWidth

        element.css
          width: "#{width + 20}px"

      element.bind 'keydown', () =>
        scope.setWidth(element.val())

      return

]
