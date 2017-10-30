angular.module("perform").controller "MultiUserReviewCtrl", [

  "$scope"
  "$rootScope"
  "$stateParams"
  "Reviews"
  "WS"
  "BG"
  "Utils"
  "Portal"
  "users"
  "$state"
  "$timeout"
  "Cache"
  "Reviews"
  "reviews"

  ($scope, $rootScope, $stateParams, Reviews, WS, BG, Utils, Portal, users, $state, $timeout, $interval, Cache, reviews) ->

    $scope.review_year = $stateParams.review_year
    $scope.template_id = reviews[0].latest_review.template_id
    $scope.review_type = $state.current.data.review_type

    $scope.getSaveStatus = () -> Reviews.save

    $scope.$watch 'getSaveStatus()', (newValue, oldValue) ->
      if newValue
        # First time the service (Reviews) get initialized, there isnt any value.
        if newValue[$scope.review_type].status == 'Saving ..' || newValue[$scope.review_type].status == 'Editing ..' || newValue[$scope.review_type].status == 'Updating ..'
          $scope.save.status = newValue[$scope.review_type].status
        else
          $scope.save.status = 'All changes saved'
        $scope.save.freq   = newValue.freq
        $scope.save.last   = newValue[$scope.review_type].last
    , true

    if $state.$current.data?.section
      $scope.sectionName = $state.$current.data.section
    else
      $scope.sectionName = $stateParams.section



    return

]
