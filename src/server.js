var express = require('express');
var server = express();
var request = require('request');
var domain = require('domain').create();
var node = 8888;
var java = 8887;

function setupStoreFrontCall(method, nodePath, apiRequest) {
  server.get('/' + nodePath, function (serverRequest, response) {
    var url = 'http://localhost:' + java + '/rest/appdserver' + apiRequest;
    var query = {};
    for (var key in serverRequest.query) {
      if (serverRequest.query.hasOwnProperty(key)) {
        query[key] = serverRequest.query[key];
      }
    }

    data = {
      method: method,
      url: url
    };

    if (method == 'POST') {
      data['form'] = query;
    } else if (method == 'GET') {
      data['qs'] = query;
    } else {
      if (query.hasOwnProperty("id")) {
        data.url += "/" + query.id;
      }
      if (query.hasOwnProperty("name")) {
        data.url += "/" + query.name;
      }
      if (query.hasOwnProperty("stock")) {
        data.url += "/" + query.stock;
      }
    }

    request(data, function (error, apiResponse, body) {
      if (apiResponse && body) {
        response.send(body);
      } else {
        response.send("[]");
      }
    });
  });
}

server.use(express.static(__dirname + '/public'));
setupStoreFrontCall('GET', 'retrieveAll', '/all');
setupStoreFrontCall('GET', 'retrieve', '');
setupStoreFrontCall('POST', 'add', '');
setupStoreFrontCall('PUT', 'update', '/put');
setupStoreFrontCall('DELETE', 'delete', '/del');
setupStoreFrontCall('GET', 'exceptionJava', '/exception');
setupStoreFrontCall('GET', 'exceptionSql', '/sqlexception');
setupStoreFrontCall('GET', 'slowrequest', '/slowrequest');

domain.on('error', function (err) {
});

server.get('/exception', function (serverRequest, response) {
  domain.run(function () {
    throw new Error('User triggered exception!');
  });
  response.send("[]");
});

server.listen(node, 'localhost', function () {
  console.log('Node Server Started');
});
server.on('error', function (e) {
  console.log('Node Server Failed');
  console.log(e);
});