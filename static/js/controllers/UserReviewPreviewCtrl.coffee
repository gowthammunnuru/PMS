angular.module("perform").controller "UserReviewPreviewCtrl", [

  "$scope"
  "$stateParams"
  "WS"
  "Portal"
  "Utils"
  "user"
  "$state"
  "Cache"
  "Auth"
  "Reviews"
  "review"

  ($scope, $stateParams, WS, Portal,Utils, user, $state, Cache, Auth, Reviews, review) ->

    if review?.latest_template
      $scope.sections = (section for sectionName, section of review.latest_template.section)
      $scope.template_id = review.latest_template.template_id
      console.log($scope.sections)

    $scope.review_metadata = review.metadata

    $scope.latest_review = review.latest_review

    $scope.review_type   = $state.current.data.review_type
    $scope.review = Reviews.getset(review.latest_review, $scope.review_type)
    $scope.review_payload = review

    if $state.$current.data?.section
      $scope.sectionName = $state.$current.data.section
    else
      $scope.sectionName = $stateParams.section

    # Check to see if its the user accessing his/her performce review
    $scope.restrictedAccess = (Auth.getUser().uid is $scope.user.uid) and ($scope.review_type is 'review')

    $scope.user        = user
    $scope.review_year = $stateParams.review_year
    $scope.review_name = $stateParams.review_name

    $scope.last_edit_time = (Utils.localtime(review.latest_review.datetime).format('LLL'))

    $scope.goToReview = (review) ->

      if review.review_type == 'self-review'
        state = 'user_self_review_year.start'
      else
        state = 'user_review_year.start'

      $state.go state,
        uid: review.uid
        review_year: review.year
        review_name: review.rname

    return
]
