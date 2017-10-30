angular.module("perform").filter "UserFilter", [

  "Auth"

  (Auth) ->

    (review) ->

      currUser = Auth.getUser().uid

      y = (x for x in review when x.uid != currUser)

      console.log(y)

      return y

]
