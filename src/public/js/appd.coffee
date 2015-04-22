app = angular.module 'appdsampleapp', []

app.config [
  '$httpProvider',
  ($httpProvider) ->
    $httpProvider.interceptors.push [
      '$q', '$rootScope',
      ($q, $rootScope) ->
        if not $rootScope.loaders?
          $rootScope.loaders = 0

        request: (request) ->
          $rootScope.loaders++
          request
        requestError: (error) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          error
        response: (response) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          response
        responseError: (error) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          error
    ]
]

app.controller 'AdminController', [
  '$scope', '$http', '$rootScope', '$timeout'
  ($scope, $http, $rootScope, $timeout) ->
    $scope.products = []
    $scope.ready = false

    setupProductUpdate = (product) ->
      product.loading = false
      product.stock = parseInt product.stock, 10
      product.save = (decrement) ->
        if product.name == "" or not angular.isNumber product.stock
          return
        useStock = if decrement then product.stock - 1 else product.stock
        $http.get '/update',
          method: 'GET'
          params:
            id: product.id
            name: product.name
            stock: if useStock < 0 then 0 else useStock
        .success (returnProduct) ->
          product.stock = parseInt returnProduct[0].stock, 10
          product.lodaing = false
        .error ->
          alert 'Unable to update the product.'
          product.loading = false
      product.delete = ->
        $http.get '/delete',
          method: 'GET'
          params:
            id: product.id
        .success ->
          product.loading = false
          for lookup of $scope.products
            if not $scope.products.hasOwnProperty lookup then continue
            if $scope.products[lookup].id == product.id
              $scope.products.splice lookup, 1
              break
        .error ->
          alert 'Unable to delete the product.'
          product.loading = false
      $scope.products.push product

    $http.get '/retrieveAll'
      .success (data) ->
        for product of data
          if not data.hasOwnProperty product then continue
          setupProductUpdate data[product]
        $scope.ready = true
        null

    $scope.looping = false
    $scope.recursive = 25
    activeLoop = 0
    $scope.getActiveLoop = ->
      if Number(activeLoop) or activeLoop == 0
        if activeLoop > 0
          return 'Sending Request #' + activeLoop + '...'
        else
          return ''
      activeLoop
    recurses = 0

    performLoopGet = ->
      activeLoop++
      $http.get '/retrieveAll'
        .success ->
          if activeLoop < recurses
            $timeout performLoopGet, 500
          else
            activeLoop = 'Completed ' + recurses + ' Requests'
            $scope.looping = false
        .error ->
          activeLoop = 'Error'
          $scope.looping = false

    $scope.loopingGet = ->
      $scope.looping = true
      activeLoop = 0
      recurses = $scope.recursive
      performLoopGet()

    $scope.slowRequest = false
    $scope.slowRequestGet = ->
      $scope.slowRequest = true
      $http.get '/slowrequest'
      .success ->
        $scope.slowRequest = false
      .error ->
        $scope.slowRequest = false

    $scope.newName = ""
    $scope.newStock = 0

    $scope.loadingNew = false
    $scope.addNew = ->
      if $scope.newName == "" or not angular.isNumber $scope.newStock
        return
      $scope.loadingNew = true
      $http.get '/add',
        method: 'GET'
        params:
          name: $scope.newName
          stock: $scope.newStock
      .success (data) ->
        $scope.loadingNew = false
        $scope.newName = ""
        $scope.newStock = 0
        setupProductUpdate data[0]
      .error ->
        alert 'Unable to add new product.'
        $scope.loadingNew = false

    if not $rootScope.exceptions?
      $rootScope.exceptions = 0
    if not $rootScope.exceptionsJava?
      $rootScope.exceptionsJava = 0
    if not $rootScope.exceptionsSql?
      $rootScope.exceptionsSql = 0

    $scope.raising = false
    $scope.getExceptions = ->
      $rootScope.exceptions
    $scope.raiseException = ->
      $scope.raising = true
      $http.get '/exception',
        method: 'GET'
      .success (data) ->
        $rootScope.exceptions++
        $scope.raising = false
      .error ->
        alert 'Unable to raise exception.'
        $scope.raising = false
    $scope.raisingJava = false
    $scope.getJavaExceptions = ->
      $rootScope.exceptionsJava
    $scope.raiseJavaException = ->
      $scope.raisingJava = true
      $http.get '/exceptionJava',
        method: 'GET'
      .success (data) ->
        $rootScope.exceptionsJava++
        $scope.raisingJava = false
      .error ->
        alert 'Unable to raise exception.'
        $scope.raisingJava = false
    $scope.raisingSql = false
    $scope.getSqlExceptions = ->
      $rootScope.exceptionsSql
    $scope.raiseSqlException = ->
      $scope.raisingSql = true
      $http.get '/exceptionSql',
        method: 'GET'
      .success (data) ->
        $rootScope.exceptionsSql++
        $scope.raisingSql = false
      .error ->
        alert 'Unable to raise exception.'
        $scope.raisingSql = false
]

app.directive 'adLoader', [
  '$rootScope',
  ($rootScope) ->
    restrict: 'E'
    templateUrl: '/partials/loader.html'
    link: () ->
      if not $rootScope.loaders?
        $rootScope.loaders = 0
      $rootScope.$on '$routeChangeStart', ->
        $rootScope.loaders++
      $rootScope.$on '$routeChangeSuccess', ->
        $rootScope.loaders--
        if $rootScope.loaders < 0 then $rootScope.loaders = 0
]

app.directive 'adProduct', ->
  restrict: 'E'
  templateUrl: '/partials/product.html'
  scope:
    product: '='
    consumeProduct: '='

