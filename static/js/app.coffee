"use strict"

app = angular.module("perform",[
  "ui.router"
  "ui.sortable"
  "ui.utils"
  "ui.bootstrap"
  "ngRoute"
  "ngSanitize"
  "ngCookies"
])

app.run ($window, $rootScope, $state, $stateParams, BG, Cache, Auth, Utils, Reviews) ->

  # Globaly expose these services
  $rootScope.$window      = $window
  $rootScope.$state       = $state
  $rootScope.$stateParams = $stateParams
  $rootScope.deferPresent = false

  $rootScope.auth = () -> Auth.getSession()
  $rootScope.Auth = Auth
  $rootScope.BG   = BG


  $rootScope.$watch 'deferPresent', (newValue, oldValue) ->
    if newValue is true
      Utils.showLoading()
    else
      Utils.hideLoading()

  $rootScope.cache = Cache

  $rootScope.$on 'connection-open', () ->
    Utils.hideConnectionLost()

  $rootScope.$on 'connection-lost', () ->
    Utils.showConnectionLost()

  $rootScope.goToHome = () ->
    if $rootScope.Auth.getStatus() and $state.current.name isnt 'landing.home'
      BG.go('landing.home', {}, {})

  $rootScope.$on "$stateChangeStart", (event, toState, toParams, fromState, fromParams) ->
    console.log("[ROUTE-CHANGE]: #{$state.current.name} -> #{toState.name}", $state.goingTo)

    if not fromState.name is 'user_review_year.start'
     if $rootScope.preventNavigation
       console.log('Unsaved changes. Preventing this move.')
       event.preventDefault()
       return

    Utils.showLoading()

    # Stop auto update while moving from user-review, multi-review or self-review
    if fromState.name is 'user_review_year.section' or fromState.name is 'multi_user_review_year.section' or fromState is 'user_self_review_year.section'
      Reviews.stopAutoUpdate()

    if toState.name isnt 'landing.login' and not Auth.getStatus()
      console.log('reject!')
      Reviews.stopAutoUpdate()

      # This means we just had an incorrect attempt at user/pass
      if $state.current.name == "landing.login"
        $state.transitionTo 'landing.login',
          auth_error: 401 # not authorized
        ,
          notify: false
      else
        $state.go 'landing.login'
        Auth.rejectState = [toState, toParams]

      Utils.hideLoading()
      event.preventDefault()

    if toState.name is "auth_error"
      toState.data.rejectState  = $state.goingTo[1]
      toState.data.rejectParams = $state.goingTo[2]

      $state.goingTo[0]?.preventDefault()
    else if not fromState.name
      console.log('XXXXXXXXXXXXXXX FIX ME XXXXXXXXXXXXXXX')
    else
      $state.goingTo = [event, toState, toParams]

  $rootScope.$on "$stateChangeSuccess", (event, toState, toParams, fromState, fromParams) ->
    console.log("[ROUTE-SUCCESS]: #{fromState.name} -> #{toState.name}")
    $state.goingTo = []
    Utils.hideLoading()
    return

  $rootScope.$on "$stateChangeError", (event, toState, toParams, fromState, fromParams) ->
    console.log(event)
    return

  Cache.getAppMetadata().then (response) ->
    $rootScope.metadata = response

  return

# Dev stuff
if window.location.host not in ["perform", "perform.ddu-india.com"]
  angular.element('#favicon').attr('href', 'static/media/images/favicon_dev.png')
