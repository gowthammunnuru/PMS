angular.module("perform").service "Utils", [

  "$rootScope"
  "$window"

  ($rootScope, $window) ->

    String::startswith ?= (s) -> @slice(0, s.length) == s
    String::endswith   ?= (s) -> s == '' or @slice(-s.length) == s
    String::lower       = -> @toLowerCase()

    @browser = (->
      ua = navigator.userAgent
      tem = undefined
      M = ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\/))\/?\s*(\d+)/i) or []
      if /trident/i.test(M[1])
        tem = /\brv[ :]+(\d+)/g.exec(ua) or []
        return "IE " + (tem[1] or "")
      if M[1] is "Chrome"
        tem = ua.match(/\bOPR\/(\d+)/)
        return "Opera " + tem[1]  if tem?
      M = (if M[2] then [
        M[1]
        M[2]
      ] else [
        navigator.appName
        navigator.appVersion
        "-?"
      ])
      M.splice 1, 1, tem[1]  if (tem = ua.match(/version\/(\d+)/i))?
      M.join " "
    )()


    @hideBrowserBanner = () ->
      $rootScope.showTopBanner = opacity: 0

    @showBrowserBanner = () ->
      @bannerMsg = "You're using an unsupported browser. Some features may not work correctly."
      $rootScope.showTopBanner = opacity: 1


    $rootScope.showLoading = false
    @showLoading = () ->
      $rootScope.showLoading = true

    @hideLoading = () ->
      $rootScope.showLoading = false

    @localtime = (dt) ->
      moment.tz(dt, 'UTC').tz(jstz.determine().name())

    $rootScope.preventNavigation = false
    @showPreventNavigation = () ->
      $rootScope.preventNavigation = true
      $window.onbeforeunload = () -> "You may lose recent changes by navigating away."
      #$window.onhashchange = () -> "You may lose recent changes by navigating away."

    @hidePreventNavigation = () ->
      $rootScope.preventNavigation = false
      $window.onbeforeunload = null
      #$window.onhashchange = null

    @showConnectionLost = () ->
      '''
      Show a banner that provides the user a way to reload the page
      '''

      $rootScope.showConnectionLostBanner = opacity: 1

    @hideConnectionLost = () ->
      '''
      Show a banner that provides the user a way to reload the page
      '''

      $rootScope.showConnectionLostBanner = opacity: 0

    return
]
