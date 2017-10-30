angular.module("perform").filter "MarkdownFilter", [

  () ->
    converter = new showdown.Converter({ extensions: ['newline'] })

    (input) ->
      if input
        converter.makeHtml(input)
      else
        input
]