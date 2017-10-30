angular.module("perform").filter "BreakNewLineFilter", [

  () ->

    (input) ->
      if input
        return input.replace(/\n/g, '<br />')
      else
        input
]
