angular.module("perform").controller "DialogBacklogDetailedStatsCtrl", [
  "$scope"
  "$state"
  "$modal"
  "$modalInstance"
  "user2dict"
  "user"
  "users_in_backlog"
  "review_rname"
  "review_year"

  ($scope, $state, $modal, $modalInstance, user2dict, user, users_in_backlog, review_rname, review_year) ->

    $scope.header_text= user2dict[user][0].cn + " - Backlog"

    $scope.filtered_users = users_in_backlog
    $scope.review_rname = review_rname
    $scope.review_year = review_year

    $scope.ok = () ->
      $modalInstance.close()

    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

    $scope.getFullName = (uid) ->
      return user2dict[uid][0].cn

    $scope.goToUserReview = (uid) ->
      $state.go 'user_review_year.start',
        uid: uid
        review_year: $scope.review_year
        review_name: $scope.review_rname

      $modalInstance.close()

    return
]
