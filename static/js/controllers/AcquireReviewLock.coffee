angular.module("perform").controller "AcquireReviewLockCtrl", [

  "$scope"
  "$stateParams"
  "$rootScope"
  "Reviews"
  "WS"
  "Portal"
  "Utils"
  "$state"
  "$timeout"
  "Cache"
  "Auth"

  ($scope, $stateParams, $rootScope, Reviews, WS, Portal, Utils, $state, $timeout, Cache, Auth) ->

    $scope.image = "/static/media/autherror/autherror-#{Math.floor(Math.random() * 4) + 1}.jpg"
    if $state.params.isCurrentlyEditedBy? == 'admin'
      $scope.lockReleased = true
    else if $state.params.isCurrentlyEditedBy?.length >= 1
      $scope.isCurrentlyEditedBy =$state.params.isCurrentlyEditedBy
    else
      $state.transitionTo('landing.home')

]