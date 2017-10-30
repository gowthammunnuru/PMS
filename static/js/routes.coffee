"use strict"

app.config ($stateProvider, $urlRouterProvider) ->

  $urlRouterProvider.otherwise('404')


#######################################################
#
#                  Landing/Home
#
#######################################################

  landing =
    name: "landing"
    url: ''
    template: '<ui-view/>'
    controller: (Auth, $state) ->
      console.log('Logged In: ', Auth.getStatus())
      if not Auth.getStatus()

        stateToGo = "landing.login"
        $state.go(stateToGo, {}, {location: false})
      else
        stateToGo = "landing.home"
        console.log("x. Going to #{stateToGo}")
        $state.go(stateToGo, {}, {location: false})

  landingLogin =
    name: 'landing.login'
    url: '/login?auth_error'
    templateUrl: 'static/partials/login.html'
    controller: 'LoginCtrl'

  landingHome =
    name: 'landing.home'
    url: '/home'
    templateUrl: 'static/partials/home.html'
    controller: 'HomeCtrl'
    resolve:
      userinfo: (Cache) ->
        Cache.getAuthUserInfo()

  $stateProvider.state(landing)
  $stateProvider.state(landingLogin)
  $stateProvider.state(landingHome)

#######################################################
#
#               Single User Reviews
#
#######################################################


  userReviewByYear =
    name: 'user_review_year'
    url: '/review/{uid:[^/+]*}/:review_year/:review_name'
    abstract: true
    data:
      review_type: 'review'
    template: '<ui-view/>'
    resolve:

      userinfo: (Cache) ->
        Cache.getAuthUserInfo()

      user: (Cache, $stateParams) ->
        Cache.getUser($stateParams.uid)

      review: (Cache, Reviews, $stateParams) ->
        Cache.getReviewByUser($stateParams.uid, $stateParams.review_year, $stateParams.review_name, 'review')

      selfReview: (Cache, Reviews, $stateParams) ->
        Cache.getReviewByUser($stateParams.uid, $stateParams.review_year, $stateParams.review_name, 'self-review')

  userReviewByYearStart =
    name: 'user_review_year.start'
    url: '?selfreview&validate&feedback'
    controller: ($scope, $state, $stateParams) ->

      $state.transitionTo 'user_review_year.section',

        uid         : $stateParams.uid,
        review_year : $stateParams.review_year
        review_name : $stateParams.review_name,
        section     : 'ratings'
        selfreview  : $stateParams.selfreview
        validate    : $stateParams.validate
        feedback    : $stateParams.feedback
      ,
        location: false
        inherit: true
        relative: $state.$current
        notify: true


  userReviewByYearSection =
    name: 'user_review_year.section'
    url: '/{section:(?!preview|settings$).*}?selfreview&validate&feedback'
    views:
      '':
        controller: 'UserCtrl'
        templateUrl: 'static/partials/user.html'
      "contents@user_review_year.section":
        controller: 'UserReviewCtrl'
        templateProvider: (Cache, Template, $stateParams) =>
          uid   = $stateParams.uid
          year  = $stateParams.review_year
          rname = $stateParams.review_name

          return Cache.getReviewByUser(uid, year, rname, 'review').then (response) ->
            response.latest_template.section[$stateParams.section].html
    resolve:
      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

      allReviews: (Cache, $stateParams) ->
        Cache.getAllReviewsForUser($stateParams.uid).then (response) ->
          response

  userReviewByYearPreview =
    name: 'user_review_year.preview'
    url: '/preview'
    views:
      '':
        templateUrl: 'static/partials/user.preview_wrapper.html'
        controller: 'UserReviewCtrl'
      "contents@user_review_year.preview":
        controller: 'UserReviewPreviewCtrl'
        templateProvider: (Cache, Template, $state, $stateParams) =>
          uid         = $stateParams.uid
          review_year = $stateParams.review_year
          review_name = $stateParams.review_name

          template = Cache.getReviewByUser(uid, review_year, review_name, 'review').then (response) ->
            sections = response.latest_template.section

            sectionTemplates = ("#{templateObj.html_mode_preview}" for sectionName, templateObj of sections)

            str  = "<page><preview-header></preview-header>#{sectionTemplates[0]}</page><pagebreak></pagebreak>"
            str += ("\n<page>\n#{t}<preview-footer></preview-footer>\n</page>" for t in sectionTemplates[1..]).join("\n\n<pagebreak></pagebreak>")

            console.log(str)
            return str


          return template

  $stateProvider.state(userReviewByYear)
  $stateProvider.state(userReviewByYearStart)
  $stateProvider.state(userReviewByYearSection)
  $stateProvider.state(userReviewByYearPreview)


#######################################################
#
#                   Multiple Users
#
#######################################################

  multiUsersReviewByYear =
    name: 'multi_user_review_year'
    url: '/review/{uids:[^/]*\\+[^/]*}/:review_year/:review_name'
    abstract: true
    data:
      review_type: 'review'
    template: '<ui-view/>'
    resolve:

      userinfo: (Cache) ->
        Cache.getAuthUserInfo()

      users: (Cache, $q, $stateParams) ->
        $q.all($stateParams.uids.split('+').map (uid) -> Cache.getUser(uid))

      reviews: (Cache, $q, $stateParams) ->

        uids = $stateParams.uids.split('+')
        year = $stateParams.review_year
        rname = $stateParams.review_name

        requests = []

        for uid in uids

          req =
            uid: uid
            year: year
            rname: rname
            review_type: 'review'

          requests.push(req)

        Cache.getReviewByUserMulti(requests)

      selfReviews: (Cache, $q, Reviews, $stateParams) ->

        uids = $stateParams.uids.split('+')
        year = $stateParams.review_year
        rname = $stateParams.review_name

        requests = []

        for uid in uids

          req =
            uid: uid
            year: year
            rname: rname
            review_type: 'self-review'

          requests.push(req)

        Cache.getReviewByUserMulti(requests)

  multiUsersReviewByYearStart =
    name: 'multi_user_review_year.start'
    url: ''
    controller: ($scope, $state, $stateParams) ->

      $state.transitionTo 'multi_user_review_year.section',
        uids    : $stateParams.uids,
        section : 'ratings'
      ,
        location: false
        inherit: true
        relative: $state.$current
        notify: true

  multiUsersReviewByYearSection =
    name: 'multi_user_review_year.section'
    url: '/:section'
    views:
      '':
        controller: 'MultiUserCtrl'
        templateUrl: 'static/partials/multiuser.html'
      "contents@multi_user_review_year.section":
        controller: 'MultiUserReviewCtrl'
        templateProvider: (Cache, Template, $stateParams) =>
          review_year = $stateParams.review_year
          review_name = $stateParams.review_name

          uids = $stateParams.uids.split('+')

          # We assume that the template_id's of all users are same at this point
          uid = uids[0]

          return Cache.getReviewByUser(uid, review_year, review_name, 'review').then (response) ->
            response.latest_template.section[$stateParams.section].html_mode_multi

  $stateProvider.state(multiUsersReviewByYear)
  $stateProvider.state(multiUsersReviewByYearStart)
  $stateProvider.state(multiUsersReviewByYearSection)


#######################################################
#
#                     Self Reviews
#
#######################################################


  userSelfReviewByYear =
    name: 'user_self_review_year'
    url: '/selfreview/{uid:[^/+]*}/:review_year/:review_name'
    abstract: true
    template: '<ui-view/>'
    data:
      review_type: 'self-review'
    resolve:

      user: (Cache, $stateParams) ->
        Cache.getUser($stateParams.uid).then (response) -> response

      review: (Cache, Reviews, $stateParams) ->
        Cache.getReviewByUser($stateParams.uid, $stateParams.review_year, $stateParams.review_name, 'self-review')

      selfReview: (Cache, Reviews, $stateParams) ->
        Cache.getReviewByUser($stateParams.uid, $stateParams.review_year, $stateParams.review_name, 'self-review')

      authCheck: (selfReview, Auth, $state)->
        #Ensures that reviewer cannot view or modify review until committed
        if _.contains(_.pluck(selfReview.permitted_users, "uid"), Auth.getUser().uid) && _.isEmpty(selfReview.timeline.COMMIT_REVIEW)
          return $state.transitionTo  'auth_error', {},
            location: 'replace'
            inherit: true
            notify: true
        return

  userSelfReviewByYearStart =
    name: 'user_self_review_year.start'
    url: '?validate'
    controller: ($scope, $state, $stateParams) ->

      $state.transitionTo 'user_self_review_year.section',
        uid     : $stateParams.uid,
        section : 'ratings'
        validate: $stateParams.validate
      ,
        location: false
        inherit: true
        relative: $state.$current
        notify: true


  userSelfReviewByYearSection =
    name: 'user_self_review_year.section'
    url: '/{section:(?!preview|settings$).*}?validate'
    views:
      '':
        controller: 'UserCtrl'
        templateUrl: 'static/partials/user.html'
      "contents@user_self_review_year.section":
        controller: 'UserReviewCtrl'
        templateProvider: (Cache, Template, $stateParams) =>
          uid         = $stateParams.uid
          review_year = $stateParams.review_year
          review_name = $stateParams.review_name

          return Cache.getReviewByUser(uid, review_year, review_name, 'self-review').then (response) ->
            response.latest_template.section[$stateParams.section].html
    resolve:
      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

      allReviews: (Cache, $stateParams) ->
        Cache.getAllReviewsForUser($stateParams.uid).then (response) ->
          response

  userSelfReviewByYearPreview =
    name: 'user_self_review_year.preview'
    url: '/preview'
    views:
      '':
        templateUrl: 'static/partials/user.preview_wrapper.html'
        controller: 'UserReviewCtrl'
      "contents@user_self_review_year.preview":
        controller: 'UserReviewPreviewCtrl'
        templateProvider: (Cache, Template, $stateParams) =>
          uid         = $stateParams.uid
          review_year = $stateParams.review_year
          review_name = $stateParams.review_name

          template = Cache.getReviewByUser(uid, review_year, review_name, 'self-review').then (response) ->
            sections = response.latest_template.section

            sectionTemplates = ("#{templateObj.html_mode_preview}" for sectionName, templateObj of sections)

            str  = "<page><preview-header></preview-header>#{sectionTemplates[0]}</page><pagebreak></pagebreak>"
            str += ("\n<page>#{t}</page>" for t in sectionTemplates[1..]).join("\n\n<pagebreak></pagebreak>")


            console.log(str)
            return str


          return template

  $stateProvider.state(userSelfReviewByYear)
  $stateProvider.state(userSelfReviewByYearStart)
  $stateProvider.state(userSelfReviewByYearSection)
  $stateProvider.state(userSelfReviewByYearPreview)

#######################################################
#
#                  9 Box
#
#######################################################
#
  nineBoxStart =
    name: '9box.start'
    url: ''
    templateUrl: 'static/partials/9box.html'
    controller: '9BoxCtrl'

  nineBox =
    name: '9box'
    url: '/9box/{uids:[^/]*}/:review_year/:review_name'
    abstract: true
    template: '<ui-view/>'
    data:
      review_type: 'review'
    resolve:

      userinfo: (Cache) ->
        Cache.getAuthUserInfo()

      users: (Cache, $q, $stateParams) ->
        $q.all($stateParams.uids.split('+').map (uid) -> Cache.getUser(uid))

      reviews: (Cache, $q, $stateParams) ->

        uids = $stateParams.uids.split('+')
        year = $stateParams.review_year
        rname = $stateParams.review_name

        requests = []

        for uid in uids

          req =
            uid: uid
            year: year
            rname: rname
            review_type: 'review'

          requests.push(req)

        Cache.getReviewByUserMulti(requests)

      selfReviews: (Cache, $q, Reviews, $stateParams) ->

        uids = $stateParams.uids.split('+')
        year = $stateParams.review_year
        rname = $stateParams.review_name

        requests = []

        for uid in uids

          req =
            uid: uid
            year: year
            rname: rname
            review_type: 'self-review'

          requests.push(req)

        Cache.getReviewByUserMulti(requests)

      template: (Cache, $stateParams, Template) ->

        uids = $stateParams.uids.split('+')

        uid = uids[0] # Assume that all have same template_id

        year  = $stateParams.review_year
        rname = $stateParams.review_name

        Cache.getReviewByUser(uid, year, rname, 'review').then (response) ->

          templateID = response.latest_template.template_id

          Template.getTemplate(templateID, year, rname)



  $stateProvider.state(nineBox)
  $stateProvider.state(nineBoxStart)

#######################################################
#
#                  Leave Feedback
#
#######################################################

  feedback =
    name: 'feedback'
    url: '/feedback'
    abstract: true
    template: '<ui-view/>'

  feedbackForm =
    name: 'feedback.form'
    url: '/{uids:[^/]+}'
    templateUrl: 'static/partials/feedback.form.html'
    controller: 'FeedbackFormCtrl'
    resolve:
      users: (Cache, $q, $stateParams) ->
        $q.all($stateParams.uids.split('+').map (uid) -> Cache.getUser(uid))

      feedbacks: (Cache, $q, $stateParams) ->
        $q.all($stateParams.uids.split('+').map (uid) -> Cache.getFeedback(uid))

  $stateProvider.state(feedback)
  $stateProvider.state(feedbackForm)

#######################################################
#
#                     Admin
#
#######################################################


  admin =
    name: 'admin'
    url: '/admin'
    abstract: true
    template: '<ui-view/>'

  adminMgmtLanding =
    name: 'admin.mgmt'
    url: '/manage'
    templateUrl: 'static/partials/adminMgmt.html'
    controller: 'AdminMgmtCtrl'
    resolve:
      allAdmins: (Cache)->
        Cache.getAllAdmins().then (response) ->
          response
      allUsers: (Portal, Auth)->
        Portal.getAllUsersByLocation(Auth.getUser().organization).then (response) ->
          response



  adminLanding =
    name: 'admin.landing'
    url: ''
    templateUrl: 'static/partials/admin.html'
    controller: 'AdminCtrl'
    resolve:
      adminData: (Cache, $stateParams) ->
        Cache.getAdminData()

      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

  setupReviews =
    name: 'admin.reviews'
    url: '^/setup/reviews/:review_year/:review_name?desc&filter'
    templateUrl: 'static/partials/setup.reviews.html'
    controller: 'SetupReviewsCtrl'
    resolve:
      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

      allTemplates: (Template, $stateParams) ->
        Template.getAllTemplateTypes($stateParams.review_year, $stateParams.review_name)

      allReviews: (Cache, $stateParams) ->
        Cache.getAllReviewsByYear($stateParams.review_year, $stateParams.review_name)

  setupReviewsFiltered =
    name: 'admin.reviews.filtered'
    url: ''
    controller: () ->
      $state.transitionTo 'admin.reviews',
        filter: resultFilter
        review_year: review_year
        review_name: review_name
      ,
        location: true
        inherit = true
        relative: $state.$current
        notify: true

  setupTemplates =
    name: 'admin.templates'
    url: '^/setup/templates/:review_year/:review_name'
    abstract: true
    template: '<ui-view/>'

  setupTemplatesStart =
    name: 'admin.templates.start'
    url: ''
    templateUrl: 'static/partials/setup.templates.html'
    controller: 'SetupTemplatesCtrl'
    resolve:
      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

      allTemplates: (Template, $stateParams) ->
        Template.getAllTemplateTypes($stateParams.review_year, $stateParams.review_name)

      allReviews: (Cache, $stateParams) ->
        Cache.getAllReviewsByYear($stateParams.review_year, $stateParams.review_name)

  setupTemplatesPreviewTemplate =
    name: 'admin.templates.preview_template'
    url: '/preview'
    data:
      review_type: 'weights-performance'
    abstract: true
    template: '<ui-view/>'

  setupTemplatesPreviewTemplateRender =
    name: 'admin.templates.preview_template.render'
    url: '?template_id&section&review_type'
    resolve:
      allUsers: (Cache) ->
        Cache.getAllUsers().then (response) ->
          response

      user: (Cache, $stateParams, Auth) ->
        Cache.getUser(Auth.getUser().uid)

      review: (Cache, $stateParams, Auth) ->
        $stateParams.review_type ?= "weights-performance"
        Cache.getReviewByUser($stateParams.template_id, $stateParams.review_year, $stateParams.review_name, $stateParams.review_type)

      selfReview: (Cache, $stateParams, Auth) ->
        $stateParams.review_type ?= "weights-performance"
        Cache.getReviewByUser($stateParams.template_id, $stateParams.review_year, $stateParams.review_name, $stateParams.review_type)

      allReviews: (Cache, $stateParams, Auth) ->
        Cache.getAllReviewsForUser(Auth.getUser().uid).then (response) ->
          response

    views:
      '':
        controller: 'UserCtrl'
        templateUrl: 'static/partials/setup.templates.preview.html'
      "contents@admin.templates.preview_template.render":
        controller: 'UserReviewCtrl'
        templateProvider: (Template, $state, $stateParams) =>

          template_id = $stateParams.template_id
          year        = $stateParams.review_year
          rname       = $stateParams.review_name

          $stateParams.section     ?= "ratings"
          $stateParams.review_type ?= "weights-performance"

          return Template.getTemplate(template_id, year, rname).then (response) =>
            response.contents.section[$stateParams.section].html


  $stateProvider.state(admin)
  $stateProvider.state(adminLanding)
  $stateProvider.state(adminMgmtLanding)
  $stateProvider.state(setupReviews)
  $stateProvider.state(setupReviewsFiltered)
  $stateProvider.state(setupTemplates)
  $stateProvider.state(setupTemplatesStart)
  $stateProvider.state(setupTemplatesPreviewTemplate)
  $stateProvider.state(setupTemplatesPreviewTemplateRender)


#######################################################
#
#                     Errors
#
#######################################################

  fourOfour =
    name: '404'
    url: '/404'
    templateUrl: 'static/partials/404.html'


  authError =
    name: 'auth_error'
    url: '/denied'
    templateUrl: 'static/partials/autherror.html'
    controller: 'AuthErrorCtrl'
    data:
      rejectState: 'x'
      rejectParams: 'y'

  editingInProgress =
    name: 'editing_in_progress'
    url:'/wait'
    controller: 'AcquireReviewLockCtrl'
    templateUrl:'static/partials/editingInProgress.html'
    params:
      isCurrentlyEditedBy:null

        

  fiveHundred =
    name: 'error'
    url: '/fatal'
    templateUrl: 'static/partials/500.html'

  $stateProvider.state(fourOfour)
  $stateProvider.state(editingInProgress)
  $stateProvider.state(authError)
  $stateProvider.state(fiveHundred)

  return
