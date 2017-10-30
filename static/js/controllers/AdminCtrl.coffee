angular.module("perform").controller "AdminCtrl", [

  "$scope"
  "$state"
  "$stateParams"
  "allUsers"
  "adminData"
  "WS"
  "$modal"
  "Auth"

  ($scope, $state, $stateParams, allUsers, adminData, WS, $modal, Auth) ->

    $scope.review =
      type: "review"

    $scope._uidToUser = (listOfUsers) ->
      uid2dict = _.groupBy allUsers, (user) ->
        if user.uid != ""
          return user.uid
        else
          return user.cn

      return uid2dict

    $scope.show_archived = false
    $scope.data  = adminData

    $scope.data.active_review_types = []
    $scope.data.archived_review_types = []
    $scope.data.active_review_types.push(x) for x in adminData.review_types when x.status == 'active'
    $scope.data.archived_review_types.push(x) for x in adminData.review_types when x.status == 'archived'
    $scope.data.reviews = _.groupBy $scope.data.review_types, (review) -> return "#{review.year}-#{review.rname}"

    if $scope.data.active_review_types
        console.log "#{$scope.data.active_review_types.length} active review types"

    if $scope.data.archived_review_types
        console.log "#{$scope.data.archived_review_types.length} archived review types"
    $scope.users=[]
    authUser = Auth.getUser()
    for x in allUsers
      if (x.active && x.organization == authUser.organization && x.location.id.indexOf('china-offsite') == -1)
        $scope.users.push(x)
    $scope.user2dept = $scope._uidToUser()
    $scope.backlog = []

    $scope.allUsersByDept = _.groupBy $scope.users, (x) -> x.ou

    $scope.showCreateForm = if not $scope.data.active_review_types.length then true else false

    # This is the selected review
    if $scope.data.active_review_types.length > 0
      $scope._selected_review_type = $scope.data.active_review_types[0]
      $scope.selectedReview = "#{$scope._selected_review_type.year}-#{$scope._selected_review_type.rname}"

    $scope.keypress = (event, params) ->
      # Enter Key
      if event.keyCode == 13
        $scope.createReview(params)

    $scope.createReview = (params) ->
      params.rname = params.desc?.replace(/[^\w\s]/gi,'').replace(/\ /g, '-').toLowerCase()
      $state.go('admin.reviews', {review_year: params.year, review_name: params.rname, desc: params.desc})

    $scope.displayStats = (review_type) ->
      ###
      Change the selected review - and also update the stats
      ###
      $scope._selected_review_type = review_type
      $scope.selectedReview = "#{$scope._selected_review_type.year}-#{$scope._selected_review_type.rname}"
      grouped_reviews = _.groupBy $scope.data.latest_reviews, (review) -> return "#{review.year}-#{review.rname}"
      $scope.user2dept = $scope._uidToUser()
      grouped_dept = _.groupBy grouped_reviews[$scope.selectedReview], $scope._group_dept
      WS.fetchBacklogStats(review_type.year, review_type.rname).then (response) ->
        $scope._sortByKey(response,'count')
        if response.length > 6
          response = response.slice(0,6)
        $scope.backlog = response
        return response
      return

    $scope._sortByKey = (array, key) ->
      array.sort (a, b) ->
        x = a[key]
        y = b[key]
        if x < y then 1 else if x > y then -1 else 0

    $scope._getLocalUserCount = () ->
      ###
      Returns the number of people at the same site as the logged in user
      ###
      authUser = Auth.getUser()
      count = 0
      for x in allUsers
        if (x.active && x.organization == authUser.organization && x.location.id.indexOf('china-offsite') == -1)
          count += 1

      return count

    $scope._getLocalUserCountByDept = () ->
      ###
      Returns the number of people by department at the same site as the logged in user
      ###
      authUser = Auth.getUser()
      count = {}
      for x in $scope.users
        if (x.active && x.organization == authUser.organization && x.location.id.indexOf('china-offsite') == -1)
          if not count.hasOwnProperty x.ou
            count[x.ou] = 0

          count[x.ou] += 1

      return count

    $scope._group_dept = (review) ->
      u = $scope.user2dept[review.uid]

      if not u
        # TODO evaluate if there should be an error here
        return 'Not found'

      return u[0].ou

    $scope.showDepartmentStats = (reviewKey) ->
      ###
      Shows the department specific statistics. This is specific to the review of type rname
      ###

      $scope.percent_dept = {}
      num_local_users = $scope._getLocalUserCount()
      num_local_by_dept = $scope._getLocalUserCountByDept()

      if $scope.review.type is "self-review"
        groupedByYearAndRname = _.groupBy $scope.data['self-reviews'], (review) -> return "#{review.year}-#{review.rname}"
      else
        groupedByYearAndRname = _.groupBy $scope.data.latest_reviews, (review) -> return "#{review.year}-#{review.rname}"

      stages = ['SET_TEMPLATE', 'SET_REVIEWER', 'SETUP_DONE', 'REVIEW_DRAFT', 'COMMIT_REVIEW', 'PUBLISH_REVIEW', 'READY2PUBLISH', 'ACKNOWLEDGE_REVIEW']

      groupedByDept = _.groupBy groupedByYearAndRname[reviewKey], $scope._group_dept

      dept_percent = {}
      dept_count = {}
      for dept in _.uniq((x.ou for x in $scope.users))
        dept_percent[dept] = {}
        dept_count[dept] = {}

        if $scope.review.type is "review"
          groupedByStatus = _.groupBy groupedByDept[dept], (review) -> return review.reviews.change_type
        else
          groupedByStatus = _.groupBy groupedByDept[dept], (review) -> return review.selfReviews.change_type

        for stage in stages
          if groupedByStatus.hasOwnProperty stage

            dept_percent[dept][stage] = groupedByStatus[stage].length*100 / num_local_by_dept[dept]
            dept_count[dept][stage] = groupedByStatus[stage].length

          else
            dept_percent[dept][stage] = 0
            dept_count[dept][stage] = 0

        dept_count[dept]['UNASSIGNED']   = num_local_by_dept[dept] - $scope.sum(_.values(dept_count[dept])) + dept_count[dept]['SET_TEMPLATE'] + dept_count[dept]['SET_REVIEWER']
        dept_percent[dept]['UNASSIGNED'] = dept_count[dept]['UNASSIGNED'] * 100 / num_local_by_dept[dept]

      $scope.dept_percent = dept_percent
      $scope.dept_count = dept_count

      return

    $scope.sum = (arr) -> _.reduce arr, (sum, el) -> sum + el


    $scope.displayDetailedStats = (review, dept, status) ->
      ###
      Displays a lightbox and shows details stats of the department selected
      ###
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-detailed-stats.html'
        controller: 'DialogDetailedStatsCtrl'
        size: 'lg'
        windowClass: 'dialog-detailed-stats'
        resolve:
          dept: () ->
            # Send the department we're checking out
            return dept

          status: () ->
            # the review status we want to view
            return status

          users: () ->
            # Send the users that belong to this department
            users = []
            for u in $scope.users
              if u.ou == dept
                users.push u.uid
            return users

          user2dict: () ->
            return $scope.user2dept

          dept_reviews: () ->
            # Send the review details!
            console.log()
            if $scope.review.type is "self-review"
              groupedByYearAndRname = _.groupBy $scope.data['self-reviews'], (review) -> return "#{review.year}-#{review.rname}"
            else
              groupedByYearAndRname = _.groupBy $scope.data.latest_reviews, (review) -> return "#{review.year}-#{review.rname}"
            groupedByDept = _.groupBy groupedByYearAndRname[$scope.selectedReview], $scope._group_dept
            return groupedByDept[dept]

          review_rname: () ->
            return $scope._selected_review_type.rname

          review_year: () ->
            return $scope._selected_review_type.year

          review_type: () ->
            return $scope.review.type

      dialog.result.then () ->
        return
      return

    $scope.displayDetailedOverallStats = (status) ->
      ###
      Displays a lightbox and shows details stats of the department selected
      ###
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-detailed-stats.html'
        controller: 'DialogDetailedStatsCtrl'
        size: 'lg'
        windowClass: 'dialog-detailed-stats'
        resolve:
          dept: () ->
            # Displaying overall info
            return "Overall"

          status: () ->
            # the review status we want to view
            return status

          users: () ->
            # Send all users
            users = []
            for u in $scope.users
              users.push u.uid
            return users

          user2dict: () ->
            return $scope.user2dept

          dept_reviews: () ->
            # Send the review details!
            console.log()
            if $scope.review.type is "self-review"
              groupedByYearAndRname = _.groupBy $scope.data['self-reviews'], (review) -> return "#{review.year}-#{review.rname}"
            else
              groupedByYearAndRname = _.groupBy $scope.data.latest_reviews, (review) -> return "#{review.year}-#{review.rname}"
            return groupedByYearAndRname[$scope.selectedReview]

          review_rname: () ->
            return $scope._selected_review_type.rname

          review_year: () ->
            return $scope._selected_review_type.year

          review_type: () ->
            return $scope.review.type

      dialog.result.then () ->
        return
      return

    $scope.displayDetailedBacklogStats = (year, review, user) ->
      ###
      Displays a lightbox and shows details stats of the user backlog
      ###
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-detailed-stats.html'
        controller: 'DialogBacklogDetailedStatsCtrl'
        size: 'lg'
        windowClass: 'dialog-detailed-backlog-stats'
        resolve:
          user: () ->
            # The user whose backlog we want
            return user

          user2dict: () ->
            return $scope.user2dept

          users_in_backlog: () ->
            #Send the review details!
            user_reviews = []
            for r in $scope.data.latest_reviews
              if r.rname == review && r.year = year && r.reviews.all_reviewers.indexOf(user) != -1 && r.reviews.change_type in ['SETUP_DONE','REVIEW_DRAFT', 'COMMIT_REVIEW', 'READY2PUBLISH']
                user_reviews.push r.uid
            return user_reviews

          review_rname: () ->
            return $scope._selected_review_type.rname

          review_year: () ->
            return $scope._selected_review_type.year

      dialog.result.then () ->
        return
      return

    $scope.archiveReview = (review) ->
      WS.archiveReview review.year, review.rname
      return

    $scope.unarchiveReview = (review) ->
      WS.unarchiveReview review.year, review.rname
      return

    $scope.showOverallStats = (reviewKey) ->
      ###
      Setup the progress bars on the individual reviews (on the left side)
      ###

      # Group all reviews by the review name and year, key = year-rname
      $scope.selectedReview = "#{$scope._selected_review_type.year}-#{$scope._selected_review_type.rname}"

      if $scope.review.type is "self-review"
        groupedByYearAndRname = _.groupBy $scope.data['self-reviews'], (review) -> return "#{review.year}-#{review.rname}"
      else
        groupedByYearAndRname = _.groupBy $scope.data.latest_reviews, (review) -> return "#{review.year}-#{review.rname}"

      $scope.percentage = {}
      $scope.overall_count = {}

      num_local_users = $scope._getLocalUserCount()
      num_local_by_dept = $scope._getLocalUserCountByDept()
      $scope.depts = Object.keys(num_local_by_dept)

      $scope.percentage[reviewKey] = {}
      $scope.overall_count[reviewKey] = {}

      # The progress bars ----------
      # Unassigned -> Grey
      # SET_TEMPLATE -> Assigned (orange)
      # REVIEW_DRAFT -> WIP (orange)
      # COMMIT_REVIEW -> Committed (light green)
      # READY2PUBLISH -> Ready to Publish (light green)
      # PUBLISH_REVIEW -> Finalized (green)
      # ACKNOWLEDGE_REVIEW -> Acknowledged (dark-green)

      assignedReviews = 0
      countReviews = {}
      totalReviews = 0

      if $scope.review.type is "self-review"
        groupedByStatus = _.groupBy groupedByYearAndRname[reviewKey], (review) -> return review.selfReviews.change_type
      else
        groupedByStatus = _.groupBy groupedByYearAndRname[reviewKey], (review) -> return review.reviews.change_type

      stages = ['SET_TEMPLATE', 'SET_REVIEWER', 'SETUP_DONE', 'REVIEW_DRAFT', 'COMMIT_REVIEW', 'READY2PUBLISH', 'PUBLISH_REVIEW', 'ACKNOWLEDGE_REVIEW']

      for category in stages
        if groupedByStatus.hasOwnProperty category
          l = groupedByStatus[category].length
          totalReviews += l

      for category in stages
        if groupedByStatus.hasOwnProperty category
          l = groupedByStatus[category].length
          $scope.overall_count[reviewKey][category] = l
        else
          $scope.overall_count[reviewKey][category] = 0

      num_assigned_users = totalReviews - $scope.overall_count[reviewKey]['SET_TEMPLATE'] - $scope.overall_count[reviewKey]['SET_REVIEWER']
      for category in stages
        if groupedByStatus.hasOwnProperty category
          l = groupedByStatus[category].length
          $scope.percentage[reviewKey][category] = l*100 / num_assigned_users
        else
          $scope.percentage[reviewKey][category] = 0

      $scope.overall_count[reviewKey]["UNASSIGNED"] = num_local_users - totalReviews + $scope.overall_count[reviewKey]['SET_TEMPLATE'] + $scope.overall_count[reviewKey]['SET_REVIEWER']
      $scope.percentage[reviewKey]["UNASSIGNED"]    = $scope.overall_count[reviewKey]["UNASSIGNED"] * 100 / num_local_users

      # for for review ends here

      #if $scope.data.active_review_types.length >0
      #  $scope._sortByKey($scope.data.active_review_types, 'year')
      #  $scope.displayStats $scope.data.active_review_types[0]

      return

    if $scope.data.active_review_types.length >0
      $scope._sortByKey($scope.data.active_review_types, 'year')
      $scope.displayStats $scope.data.active_review_types[0]

    # Setup a watch - whenever the person selects a new item on the left - update the dept stats
    $scope.$watch () ->
      $scope._selected_review_type
    , (newval, oldval) ->

      if newval
        $scope.showOverallStats "#{newval.year}-#{newval.rname}"
        $scope.showDepartmentStats "#{newval.year}-#{newval.rname}"

    return

]
