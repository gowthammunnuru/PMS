"use strict"


angular.module("perform").service "Template", [

  "WS"
  "$q"

  (WS, $q) ->

    @cache = {}

    @getAllTemplateTypes = (year, rname) ->

      if not @cache.allTemplates
        WS.getAllTemplateTypes(year, rname).then (response) =>
          @cache.allTemplates = response
          return response
      else
        allTemplates = @cache.allTemplates
        return $q.when(allTemplates)


    @getTemplate = (templateID, year, rname) =>

      @getAllTemplateTypes(year, rname).then (response) =>
        return response[templateID]

    return

]
