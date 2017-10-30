"use strict"

angular.module("perform").service "Auth", [

  "WS"
  "BG"
  "$rootScope"
  "$state"
  "Portal"
  "$q"
  "$cookieStore"

  (WS, BG, $rootScope, $state, Portal, $q, $cookieStore) ->

    # This variable stores (stateName, stateParams)
    @rejectState = []

    @getCookie = ()     ->
      data = $cookieStore.get('session')
      if not data
        data = {}
      else
        data = JSON.parse(data)

      return data

    @setCookie = (data) -> $cookieStore.put('session', JSON.stringify(data))
    @clearCookie = () -> $cookieStore.remove('session')

    @getStatus = () ->
      '''
      See if someone's logged in or not
      '''
      @getSession().status is "logged-in"

    @getUser = () ->

      if @getStatus()
        @getSession().user

    @userHasAdminMgmtRights = ()->
      if @getStatus()
        @getUser().permissions.contains('SETUP_ROLES')

    @userHasEditReviewsRights = ()->
      if @getStatus()
        @getUser().permissions.contains('SETUP_REVIEWS')

    @isAdmin = () ->
      if @getStatus()
        @getUser().is_admin

    @getSession = () ->
      '''
      Get session object
      '''
      @getCookie()

    @setSession = (response) =>
      '''
      Set session object
      '''

      if response.error
        data =
          user: ''
          status: 'auth_error'

        retVal = data

      else

        retVal = Portal.getUserInfo(response.uid).then (r) =>
          if (typeof(r) != "undefined")
            # Embed sid into this
            console.log(r)
            r.sid      = response.sid
            r.is_admin = response.is_admin

            data =
              user: r
              status: 'logged-in'

            @setCookie(data)
          else
            data =
              user: ''
              status: 'auth_error'

            retVal = data
      # retVal can be an object (auth_error) or a promise (logged-in)
      $q.when(retVal).then (retVal) ->
        # return the original "response" that was passed in
        return response

    @clearSession = () ->

      @clearCookie()

    @login = (auth) ->

      WS.login(auth).then @setSession

    @logout = () ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        $rootScope.Auth.clearSession()
        $state.go('landing')

    return

]
