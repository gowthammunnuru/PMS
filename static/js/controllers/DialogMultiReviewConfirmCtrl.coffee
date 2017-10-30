angular.module("perform").controller "DialogMultiReviewConfirmCtrl", [
  "$scope"
  "$modal"
  "$modalInstance"
  "reviews"
  "$state"

  ($scope, $modal, $modalInstance, reviews, $state) ->

    $scope.okToProceed = false

    $scope.reviews = reviews

    $scope.groups = _.groupBy(reviews, (x) -> "#{x.year}-#{x.rname}-#{x.review_type}-#{x.template_id}")

    $scope.$watch 'groups', (newValue, oldValue) ->

      if _.keys($scope.groups).length is 1
        $scope.okToProceed = true


    $scope.goToMultiReview = (reviews) ->

      uids = (x.uid for x in reviews)

      $state.go 'multi_user_review_year.start',
        uids: uids.join('+')
        review_year: reviews[0].year    # pick the first one. Doesnt matter
        review_name: reviews[0].rname

      $scope.ok()

    $scope.removeGroup = (key) ->

      delete $scope.groups[key]

    $scope.cancel = () -> $modalInstance.dismiss('cancel')
    $scope.ok     = () -> $modalInstance.close()

    return
]
