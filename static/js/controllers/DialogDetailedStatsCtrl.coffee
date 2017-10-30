angular.module("perform").controller "DialogDetailedStatsCtrl", [

  "$scope"
  "$state"
  "$modal"
  "$modalInstance"
  "user2dict"
  "users"
  "dept_reviews"
  "dept"
  "status"
  "review_rname"
  "review_year"
  "review_type"

  ($scope, $state, $modal, $modalInstance, user2dict, users, reviews, dept, status, review_rname, review_year, review_type) ->


    $scope.messages = "something only re"
    $scope.dept = dept
    $scope.reviews = reviews
    $scope.users = users
    $scope.status = status
    $scope.header_text= ""
    $scope.review_rname = review_rname
    $scope.review_year = review_year
    $scope.review_type = review_type

    $scope.filtered_users = []

    if $scope.review_type is "review"
      $scope.reviewsGroupedByStatus = _.groupBy $scope.reviews, (x) -> x.reviews.change_type
    else if $scope.review_type is "self-review"
      $scope.reviewsGroupedByStatus = _.groupBy $scope.reviews, (x) -> x.selfReviews.change_type

    for u in users
      found_review = false
      if reviews
        for r in reviews
          if r.uid == u
            console.log(" review found for: ", r.uid)
            found_review = r
            break

      if status == "UNASSIGNED"
        console.log(" for: ", u)
        if $scope.review_type is "review" && (not found_review || found_review.reviews.change_type in ['UNASSIGNED', 'SET_TEMPLATE','SET_REVIEWER'])
          $scope.filtered_users.push u
        else if $scope.review_type is "self-review" && (not found_review || found_review.selfReviews.change_type in ['UNASSIGNED', 'SET_TEMPLATE','SET_REVIEWER'])
          $scope.filtered_users.push u
        $scope.header_text="Reviewer unassigned"

      else if status == "SETUP_DONE"
        if $scope.review_type is "review" && found_review && found_review.reviews.change_type in ['SETUP_DONE']
          $scope.filtered_users.push u
        else if $scope.review_type is "self-review" && found_review && found_review.selfReviews.change_type in ['SETUP_DONE']
          $scope.filtered_users.push u
        $scope.header_text="Not yet started"

      else if status == "REVIEW_DRAFT"
        if $scope.review_type is "review" && found_review && found_review.reviews.change_type in ['REVIEW_DRAFT']
          $scope.filtered_users.push u
        else if $scope.review_type is "self-review" && found_review && found_review.selfReviews.change_type in ['REVIEW_DRAFT']
          $scope.filtered_users.push u
        $scope.header_text="In progress"

      else if status == "COMMIT_REVIEW"
        if $scope.review_type is "review" && found_review && found_review.reviews.change_type in ['COMMIT_REVIEW']
          $scope.filtered_users.push u
          $scope.header_text = "Committed"
        else if $scope.review_type is "self-review" && found_review && found_review.selfReviews.change_type in ['COMMIT_REVIEW']
          $scope.filtered_users.push u
          $scope.header_text = "Completed"

      else if status == "READY2PUBLISH"
        if $scope.review_type is "review" && found_review && found_review.reviews.change_type in ['READY2PUBLISH']
          $scope.filtered_users.push u
          $scope.header_text = "Ready to publish"
        else if $scope.review_type is "self-review" && found_review && found_review.selfReviews.change_type in ['READY2PUBLISH']
          $scope.filtered_users.push u
          $scope.header_text = "Ready to publish"

      else if status == "PUBLISH_REVIEW"
        if found_review && found_review.reviews.change_type in ['PUBLISH_REVIEW']
          $scope.filtered_users.push u

        $scope.header_text = "Published"

      else if status == "ACKNOWLEDGE_REVIEW"
        if found_review && found_review.reviews.change_type in ['ACKNOWLEDGE_REVIEW']
          $scope.filtered_users.push u

        $scope.header_text = "Acknowledged"


    # Handle inactive/resigned folks
    # all-incoming-review MINUS filtered-users => missing/inactive people
    if $scope.status not of $scope.reviewsGroupedByStatus
      $scope.reviewsGroupedByStatus[$scope.status] = []
    $scope.inactive_users = _.difference (x.uid for x in $scope.reviewsGroupedByStatus[$scope.status]), $scope.filtered_users


    $scope.ok = () ->
      $modalInstance.close()

    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

    $scope.getFullName = (uid) ->
      return user2dict[uid][0].cn

    $scope.goToUserReview = (uid) ->
      if $scope.review_type is "review"
        state = 'user_review_year.start'
      else if $scope.review_type is "self-review"
        state = 'user_self_review_year.start'
      if status isnt "UNASSIGNED"
        $state.go state,
          uid: uid
          review_year: $scope.review_year
          review_name: $scope.review_rname

        $modalInstance.close()

    $scope.filtered_users = _.sortBy $scope.filtered_users, (x) => $scope.getFullName(x)

    return
]
