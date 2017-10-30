"use strict"

angular.module("perform").directive "previewHeader", ['$window'

  ($window) ->

    restrict: 'E'
    scope: true
    templateUrl: 'static/widgets/previewHeader.html'
    link: (scope, element, attrs) ->

      scope.getCollaborators = () ->
        reviewers = (x for x in scope.review_payload.permitted_users when x.uid != scope.user.uid)
        contributors = scope.review_payload.contributors

        return reviewers.concat(contributors)
      scope.printReview = () ->
        console.log("in test function")
        $window.print()
      return

]
