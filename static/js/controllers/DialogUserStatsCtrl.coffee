angular.module("perform").controller "DialogUserStatsCtrl", [
  "$scope"
  "$state"
  "$modal"
  "$modalInstance"
  "users"
  "loggedUser"
  "status"

  ($scope, $state, $modal, $modalInstance, users, loggedUser, status) ->

    $scope.messages = ""
    $scope.filtered_users = users
    $scope.loggedUser = loggedUser
    $scope.header_text= ""

    if status == "SETUP_DONE"
      $scope.header_text="Not yet started"

    else if status == "READY2PUBLISH"
      $scope.header_text="Ready to publish"

    else if status == "REVIEW_DRAFT"
      $scope.header_text="In progress"

    else if status == "COMMIT_REVIEW"
      $scope.header_text = "Completed"

    $scope.ok = () ->
      $modalInstance.close()

    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

    $scope.goToUserReview = (user) ->
      $state.go 'user_review_year.start',
        uid: user.uid
        review_year: user.year
        review_name: user.rname

      $modalInstance.close()

    return
]
