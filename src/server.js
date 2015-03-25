var express = require('express');
var server = express();
var request = require('request');
var xml2js = require('xml2js');
var domain = require('domain').create();
var xmlParser = new xml2js.Parser();
var node = 8888;
var axis = 8887;

function setupStoreFrontCall(nodePath, apiRequest) {
  server.get('/' + nodePath, function(serverRequest, response) {
    var url = 'http://localhost:' + axis + '/axis2/services/StoreFront/' + apiRequest;
    var form = {};
    for (var key in serverRequest.query) {
      if (serverRequest.query.hasOwnProperty(key)) {
        form[key] = serverRequest.query[key];
      }
    }
    request.post({
      url: url,
      form: form
    }, function(error, apiResponse, body) {
      if (apiResponse && body) {
        xmlParser.parseString(body, function (err, result) {
          var responseKey = "ns:" + apiRequest + "Response";
          var returnKey = "ns:return";
          if (result.hasOwnProperty(responseKey) && result[responseKey].hasOwnProperty(returnKey)) {
            response.send(result[responseKey][returnKey][0]);
          } else {
              response.send("[]");
          }
        });
      } else {
        response.send("[]");
      }
    });
  });
}

server.use(express.static(__dirname + '/public'));
setupStoreFrontCall('retrieveAll', 'getAllProducts');
setupStoreFrontCall('retrieve', 'getProduct');
setupStoreFrontCall('add', 'addProduct');
setupStoreFrontCall('update', 'updateProduct');
setupStoreFrontCall('delete', 'deleteProduct');
setupStoreFrontCall('consume', 'consumeProduct');

domain.on('error', function(err) {});

server.get('/exception', function(serverRequest, response) {
    domain.run(function() {
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