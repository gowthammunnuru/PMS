angular.module("perform").controller "UserReviewSettingsCtrl", [
  "$scope"
  "$stateParams"
  "Reviews"
  "WS"
  "Portal"
  "user"
  "$state"
  "Cache"
  "Reviews"
  "$timeout"
  "review"

  ($scope, $stateParams, Reviews, WS, Portal, user, $state, $interval, Cache, $timeout, review) ->

    $scope.review = review
    $scope.user   = user

    return
]
