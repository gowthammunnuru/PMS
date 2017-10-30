angular.module("perform").controller "SetupReviewsCtrl", [

  "$scope"
  "$state"
  "$stateParams"
  "WS"
  "Utils"
  "allUsers"
  "allTemplates"
  "allReviews"
  "$filter"
  "PagerService"
  "Auth"

  ($scope, $state, $stateParams, WS, Utils, allUsers, allTemplates, allReviews, $filter, PagerService, Auth) ->

    $scope.allUsers=allUsers
    $scope.usersObj = {}
    $scope.users = []
    $scope.fullnames = []
    $scope.cnToUidMap = {}
    $scope.uidToCnMap = {}
    $scope.fullnameToUidMap = {}
    $scope.permitted_users = []
    $scope.copiedText = ''
    $scope.copyForm = ''
    $scope.isCopied = false
    $scope.reviewer = ''
    $scope.selectAllKeys = {17: false, 65: false}
    $scope.selectRightKeys = {16: false, 39: false}
    $scope.selectLeftKeys = {16: false, 37: false}
    $scope.copyKeys = {17: false, 67: false}
    $scope.randomSelectKeys = {17: false, 1: false}
    $scope.isMultipleSelected = false
    $scope.isLeftMultipleSelected = false
    $scope.singleCopied = false
    $scope.multipleReviewers = []
    $scope.currentIndex = -1
    $scope.index = 0
    $scope.leftCount = 0
    $scope.copyFirst = true
    $scope.currentCopyActiveUser = ''
    $scope.baseIndex = -1
    $scope.review_year = $stateParams.review_year
    $scope.review_name = $stateParams.review_name
    $scope.reviewKey   = "#{$stateParams.review_year}-#{$stateParams.review_name}"
    $scope.review_metadata = allReviews.metadata || {}
    user = Auth.getUser()
    $scope.allUsersByLocation=[]
    $scope.global_permitted_users=[]




    $scope.sortBy = 'ou'
    $scope.sortByText =
      cn                         :  'Name'
      ou                         :  'Department'
      physicalDeliveryOfficeName :  'Location'

    $scope.sortOrderIcon =
      true  : 'glyphicon-chevron-down'
      false : 'glyphicon-chevron-up'

    $scope.sortOrder = true

    $scope.sortColumn = (completeUserList, key) ->
      if $scope.sortBy == key
        $scope.sortOrder = !$scope.sortOrder
      else
        $scope.sortBy = key
        $scope.sortOrder = false

      return $filter('orderBy')(completeUserList, key, $scope.sortOrder)



    $scope.filterUsers = (people, key) ->
      userslist=[]
      if(!_.isEmpty(key))
        _.filter(people, (record) ->
          values = _.values(record)
          for i in values
            if typeof i != "object" && !(_.isEmpty(i)) && typeof i != "boolean"
              if (i.toLowerCase()).search((key).toLowerCase()) != -1
                userslist.push(record)
                break
          userslist
          #return _.contains(record, key)
        )
      else
        userslist=people

      return  userslist

    #Pagination properties
    $scope.setPage = (people, page) ->
      $scope.dummyItems=[]
      for i in people
        $scope.dummyItems.push(i)
      $scope.currentPage=page
      if page < 1 || page > $scope.pagingDetails?.totalPages != 0
        return $scope.users
      # get pager object from service
      $scope.pagingDetails = PagerService.GetPager(people.length, page, 100)
      # get current page of items
      $scope.users = $scope.dummyItems.slice($scope.pagingDetails.startIndex, $scope.pagingDetails.endIndex + 1)
      return $scope.users
    $scope.init = () ->

      for x in $scope.allUsers

        if x.active
         # Person without EDIT_HR permission cannot add themselves as reviewers.
          if (Auth.getUser().uid == x.uid)
            if Auth.getUser().permissions.indexOf('EDIT_HR') == -1
              continue

          $scope.users.push({site_key: x.site_key, ou: x.ou, cn: x.cn, uid: x.uid})

          $scope.cnToUidMap[x.cn] = x.uid
          $scope.uidToCnMap[x.uid] = x.cn
          $scope.fullnameToUidMap[x.cn.concat(' (',x.uid,')')] = x.uid
          $scope.usersObj[x.uid] = x

          $scope.fullnames.push(x.cn.concat(' (',x.uid,')'))
          $scope.usersObj[x.uid]?.template_id     = ""
          $scope.usersObj[x.uid]?.permitted_users = []
          $scope.usersObj[x.uid]?.locked          = false
          $scope.usersObj[x.uid]?.committed       = false

        if (x.active && x.organization == user.organization && x.location.id.indexOf('china-offsite') == -1)
          $scope.allUsersByLocation.push(x)


      # Expose
      if allReviews.reviews.length
        for review in allReviews.reviews
          if $scope.reviewKey is "#{review.year}-#{review.rname}"
            user = _.find($scope.allUsers, {"uid": review.uid})
            if user
              user.permitted_users = review.permitted_users
              user.template_id = review.template_id
              user.locked = review.locked
              user.committed = review.committed
      $scope.filteredText = $stateParams.filter
      $scope.filtered_users_results = $scope.sortColumn($scope.allUsersByLocation,'ou')
      $scope.users = $scope.setPage($scope.filtered_users_results, 1)
      if angular.isUndefined($scope.filteredText)
        $scope.filteredText = ""
    $scope.init()
    $scope.reviewSetupHandler= ( searchkey, sortkey, pageIndex)->
      $scope.filtered_users_results = $scope.sortColumn($scope.filterUsers($scope.allUsersByLocation, searchkey), sortkey)
      $scope.users= $scope.setPage($scope.filtered_users_results, pageIndex)
      if(!$scope.$$phase)
        $scope.$apply($scope.users)



    $scope.save =
      status: ''

    $scope.setSaveStatus = (token = "") ->
      if token is 'saving'
        $scope.save.status = "Saving .."
      else if token is true
        $scope.save.status = "Saved"
      else if token is false
        $scope.save.status = "Error"
      else
        $scope.save.status = ""

    $scope.getTooltip = (user) ->

      if user.committed
        return "Review is completed. Locked for further changes."
      else if user.locked
        return "Review is delivered. Locked for further changes."
      else
        return ""

    $scope.setFocus = (elem) ->
      $(elem.target).find('input[type="text"]').focus()
      ''
    $scope.templates = []
    opt =
      year : ""
      id : ""

    for temp in _.keys(allTemplates)
      opt.year = temp.split('/')[0]
      opt.id = temp.split('/')[1]
      $scope.templates.push(angular.copy(opt))



    $scope.setupReview = (data) ->
      $scope.setSaveStatus('saving')
      WS.setupReview($scope.review_year, $scope.review_name, data ).then (response) ->
        $scope.setSaveStatus(response.retVal)

    # If we're getting an initial description (usually while creating), respect that
    if $stateParams.desc
      $scope.review_metadata.desc = $stateParams?.desc
      $scope.setupReview($scope.review_metadata) # This is required because when ng-model is bound, ng-change isnt triggered

    $scope.setTemplateID = (user) ->
      $scope.setSaveStatus('saving')

      WS.setTemplateID(user.uid, $scope.review_year, $scope.review_name, user.template_id).then (response) ->
        $scope.setSaveStatus(response.retVal)

    $scope.setPermissions = (user, reviewer) ->
      if _.isEmpty(reviewer)
        reviewer= user.reviewer
      $scope.setSaveStatus('saving')
      if !user.committed && !user.locked
        user.permitted_users = (if(not (user.permitted_users?)) then  [] else user.permitted_users)
        if user.permitted_users.indexOf($scope.cnToUidMap[$scope._getCnFromFullname(reviewer)]) == -1
          user.permitted_users.push($scope.cnToUidMap[$scope._getCnFromFullname(reviewer)])
        user.reviewer=""
        $scope.globalReviewer=""
        $scope.leftCount = 0

        WS.setPermissions(user.uid, $scope.review_year, $scope.review_name, user.template_id, user.permitted_users).then (response) ->
          $scope.setSaveStatus(response.retVal)


    $scope.setGlobalPermissions = (globalReviewer)->
      for user in $scope.users
        $scope.setPermissions(user, globalReviewer)
      $scope.global_permitted_users.push(globalReviewer)


    $scope._getCnFromFullname = (fullname) ->
      fullname.split(' (')[0]

    $scope.clickFunction = (event, reviewer, user, index) ->
      if !user.committed && !user.locked
        if typeof $scope.multipleReviewers isnt 'undefined'
          $scope.multipleReviewers = []
        $scope.baseIndex = user.permitted_users.indexOf(reviewer)
        if $scope.randomSelectKeys[17] == false
          if $scope.multipleReviewers.indexOf(reviewer) == -1
            $scope.multipleReviewers = []
        if user != $scope.currentCopyActiveUser
          $scope.multipleReviewers = []
          $scope.currentCopyActiveUser = user
        if event.which == 1
          $scope.randomSelectKeys[1] = true

        if $scope.multipleReviewers.indexOf(reviewer) != -1
          $scope.multipleReviewers.splice($scope.multipleReviewers.indexOf($scope.multipleReviewers.indexOf(reviewer)), 1)
        else
          $scope.multipleReviewers.push(reviewer)

        if ($scope.randomSelectKeys[17] == true && $scope.randomSelectKeys[1] == true)
          $scope.randomSelectKeys[1] = false
          console.log(reviewer + " user: " + user)
          $scope.isMultipleSelected = true
          $scope.copyFirst = false
          $scope.copyFrom  = user

      $scope._highlightSelectedReviewers(user)

    $scope._highlightSelectedReviewers = (user) ->
      console.log $scope.multipleReviewers
      if !angular.isUndefined($scope.multipleReviewers)
        angular.element('.reviewer-tag').removeClass('selected-tag')
        (angular.element(document.querySelector('#rev-'+user.uid+'-'+reviewer )).addClass('selected-tag') for reviewer in $scope.multipleReviewers)

      ''

    $scope.pasteFunction = (user) ->
      if $scope.isCopied
        if $scope.isLeftMultipleSelected
            console.log('leftmultipleselected' + user.uid + " "+$scope.multipleReviewers )
            length = $scope.multipleReviewers.length
            index = length - 1
            while index > -1
                if $scope.multipleReviewers[index] != user.uid
                  user.reviewer = $scope.uidToCnMap[$scope.multipleReviewers[index]]
                  $scope.setPermissions(user)
                index--
        else if $scope.isMultipleSelected
            console.log('multipleselected' + user.uid + " "+$scope.multipleReviewers)
            for reviewer in $scope.multipleReviewers
                if reviewer != user.uid
                  user.reviewer = $scope.uidToCnMap[reviewer]
                  $scope.setPermissions(user)
        else if $scope.singleCopied
            console.log('singlecopied' + user.uid + " "+$scope.multipleReviewers)
            if $scope.cnToUidMap[$scope.copiedText] != user.uid
              user.reviewer = $scope.copiedText
              $scope.setPermissions(user)
      ''

    $scope.multipleSelectFunction = (event, reviewer, user) ->
      console.log("Start of function: " + $scope.multipleReviewers)
      event.preventDefault()
      if event.ctrlKey
        $scope.randomSelectKeys[17] = true

      if ($scope.copyFrom != user)
        # $scope.multipleReviewers = []
        $scope.index = 0
        $scope.leftCount = 0
      # Ctrl + Click
      if (event.which == 17 || event.which == 1)
        $scope.randomSelectKeys[event.which] = true
      # Ctrl + A
      if (event.keyCode == 17 || event.keyCode == 65)
        $scope.selectAllKeys[event.keyCode] = true
      # Shift + Left
      if (event.keyCode == 16 || event.keyCode == 37)
        $scope.selectLeftKeys[event.keyCode] = true
      # Shift + Right
      if (event.keyCode == 16 || event.keyCode == 39)
        $scope.selectRightKeys[event.keyCode] = true
      # Ctrl + C
      if (event.keyCode == 17 || event.keyCode == 67)
        $scope.copyKeys[event.keyCode] = true

      if ($scope.copyKeys[17] == true && $scope.copyKeys[67] == true)
        $scope.copyKeys[17] = false
        $scope.copyKeys[67] = false
        $scope.randomSelectKeys[17] = false
        $scope.copiedText = $scope.uidToCnMap[reviewer]
        $scope.currentIndex = user.permitted_users.indexOf(reviewer)
        $scope.copyFrom = user
        $scope.isCopied = true
        if !$scope.copyFirst
            $scope.singleCopied = false
            $scope.copyFirst = true
        else
            $scope.singleCopied = true
            $scope.isMultipleSelected = false
            $scope.isLeftMultipleSelected = false

      if ($scope.selectAllKeys[17] == true && $scope.selectAllKeys[65] == true)
        $scope.randomSelectKeys[17] = false
        $scope.selectAllKeys[17] = false
        $scope.selectAllKeys[65] = false
        $scope.isMultipleSelected = true
        $scope.singleCopied = false
        $scope.isLeftMultipleSelected = false
        $scope.multipleReviewers = user.permitted_users
        $scope.copyFrom = user
        $scope.copyFirst = false
        console.log("Ctrl + A: " + $scope.multipleReviewers)

      if ($scope.selectRightKeys[16] == true && $scope.selectRightKeys[39] == true)
        $scope.randomSelectKeys[17] = false
        $scope.selectRightKeys[39] = false
        if $scope.index == -1
          $scope.index = $scope.baseIndex +1
        if user.permitted_users.length > $scope.index
          if $scope.multipleReviewers.length ==0
            $scope.multipleReviewers.push(reviewer)
          $scope.multipleReviewers.push(user.permitted_users[$scope.index])
          $scope.isMultipleSelected = true
          $scope.singleCopied = false
          $scope.isLeftMultipleSelected = false
          $scope.copyFrom = user
          $scope.copyFirst = false
          $scope.index++

          console.log("Ctrl + Right: " + $scope.multipleReviewers)

      if ($scope.selectLeftKeys[16] == true && $scope.selectLeftKeys[37] == true)
        $scope.randomSelectKeys[17] = false
        if $scope.leftCount == 0
            $scope.multipleReviewers = []
            $scope.index = 0
        $scope.selectLeftKeys[37] = false
        $scope.leftCount++
        $scope.currentIndex = user.permitted_users.indexOf(reviewer)
        if $scope.index == 0
            $scope.index = $scope.currentIndex
        $scope.multipleReviewers.push(user.permitted_users[$scope.index])
        $scope.isLeftMultipleSelected = true
        $scope.singleCopied = false
        $scope.isMultipleSelected = false
        $scope.copyFrom = user
        $scope.copyFirst = false
        $scope.index--
        console.log("Ctrl + Left: " + $scope.multipleReviewers)

      $scope._highlightSelectedReviewers($scope.copyFrom)
      console.log("End of function: " + $scope.multipleReviewers)
      ''

    $scope.combined = (template) ->
      template.year.concat("/" + template.id)

    $scope.setGlobalTemplateID = (templateID) ->
      for user in $scope.users
        if !user.committed && !user.locked
          user.template_id = templateID

          $scope.setTemplateID(user)

    $scope.removeGlobalReviewer = (reviewer)->
      for user in $scope.users
        $scope.removeReviewer(user, reviewer)
      $scope.global_permitted_users.splice($scope.global_permitted_users.indexOf(reviewer),1)

    $scope.removeReviewer = (user,reviewer) ->
        if !user.committed && !user.locked
          user.permitted_users.splice(user.permitted_users.indexOf(reviewer),1)
          WS.setPermissions(user.uid, $scope.review_year, $scope.review_name, user.template_id, user.permitted_users).then (response) ->
            $scope.setSaveStatus(response.retVal)

    return
]
